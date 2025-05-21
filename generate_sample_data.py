import sqlite3
import random
from faker import Faker
from datetime import datetime, timedelta
import os

DB_DIR = "data/sqlite"
DB_NAME = "saas_subscriptions.db"
DB_PATH = os.path.join(DB_DIR, DB_NAME)

NUM_CUSTOMERS = 200
NUM_CAMPAIGNS = 10
MAX_SUBSCRIPTION_EVENTS_PER_CUSTOMER = 3 # Max changes (upgrade, downgrade, cancel)

fake = Faker()

def ensure_db_directory():
    """Ensures that the directory for the SQLite database exists."""
    os.makedirs(DB_DIR, exist_ok=True)

def get_db_connection():
    """Establishes a connection to the SQLite database."""
    ensure_db_directory()
    return sqlite3.connect(DB_PATH)

def create_plans(conn):
    """Creates sample subscription plans."""
    cursor = conn.cursor()
    plans_data = [
        ('Basic', 10.00, 'Access to core features, 1 user'),
        ('Pro', 25.00, 'Access to all features, 5 users, priority support'),
        ('Enterprise', 75.00, 'Unlimited access, dedicated support, API access')
    ]
    cursor.executemany("INSERT INTO plans (name, price_monthly, features) VALUES (?, ?, ?)", plans_data)
    conn.commit()
    print(f"Inserted {len(plans_data)} plans.")
    return [row[0] for row in cursor.execute("SELECT id FROM plans").fetchall()]

def create_marketing_campaigns(conn, num_campaigns):
    """Creates sample marketing campaigns."""
    cursor = conn.cursor()
    campaigns_data = []
    channels = ['Social Media', 'Email Marketing', 'PPC', 'Content Marketing', 'Referral']
    
    for _ in range(num_campaigns):
        name = f"{fake.bs().capitalize()} Campaign {random.randint(2022, 2024)}"
        start_date = fake.date_between(start_date='-2y', end_date='-1M')
        end_date = start_date + timedelta(days=random.randint(30, 90))
        budget = round(random.uniform(500, 10000), 2)
        channel = random.choice(channels)
        campaigns_data.append((name, start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d'), budget, channel))
    
    cursor.executemany(
        "INSERT INTO marketing_campaigns (name, start_date, end_date, budget, channel) VALUES (?, ?, ?, ?, ?)",
        campaigns_data
    )
    conn.commit()
    print(f"Inserted {len(campaigns_data)} marketing campaigns.")
    return [row[0] for row in cursor.execute("SELECT id FROM marketing_campaigns").fetchall()]

def create_customers(conn, num_customers, campaign_ids):
    """Creates sample customers."""
    cursor = conn.cursor()
    customers_data = []
    for _ in range(num_customers):
        name = fake.name()
        email = fake.unique.email()
        # Customers can register before, during, or after campaigns. Some might not be tied to a campaign.
        registration_date_obj = fake.date_between(start_date='-2y', end_date='today')
        registration_date = registration_date_obj.strftime('%Y-%m-%d')
        
        # 70% chance to be associated with a campaign
        marketing_campaign_id = random.choice(campaign_ids + [None]*int(len(campaign_ids)*0.3)) if campaign_ids else None
        
        customers_data.append((name, email, registration_date, marketing_campaign_id))
    
    cursor.executemany(
        "INSERT INTO customers (name, email, registration_date, marketing_campaign_id) VALUES (?, ?, ?, ?)",
        customers_data
    )
    conn.commit()
    print(f"Inserted {len(customers_data)} customers.")
    return cursor.execute("SELECT id, registration_date FROM customers ORDER BY id").fetchall()


def create_subscriptions(conn, customers_with_reg_date, plan_ids):
    """Creates sample subscriptions with lifecycles (new, churn, upgrade/downgrade)."""
    cursor = conn.cursor()
    subscriptions_data = []
    
    for customer_id, reg_date_str in customers_with_reg_date:
        current_plan_id = random.choice(plan_ids)
        # Subscription starts on or after registration
        current_start_date_obj = datetime.strptime(reg_date_str, '%Y-%m-%d') + timedelta(days=random.randint(0, 30))
        
        active_subscription = True
        
        for event_count in range(MAX_SUBSCRIPTION_EVENTS_PER_CUSTOMER + 1):
            if not active_subscription:
                break

            is_last_potential_event = (event_count == MAX_SUBSCRIPTION_EVENTS_PER_CUSTOMER)
            
            # Determine the end date for the current subscription period
            # Subscription lasts for a random period or until an event
            min_duration = 30 
            max_duration = 365 * 2 # Max 2 years for a single subscription period
            
            potential_end_date_obj = current_start_date_obj + timedelta(days=random.randint(min_duration, max_duration))
            
            # Ensure end date is not in the future for non-active statuses, unless it's an ongoing active sub
            today = datetime.today()
            if potential_end_date_obj > today and not is_last_potential_event: # if it's not the last event, it must end to have another event
                 potential_end_date_obj = today - timedelta(days=random.randint(1,30)) # make it end in the past
            
            if potential_end_date_obj <= current_start_date_obj: # Ensure end date is after start date
                potential_end_date_obj = current_start_date_obj + timedelta(days=min_duration)


            # Decide event: continue active, upgrade, downgrade, cancel
            # On the first event (initial subscription), it's always 'active'
            if event_count == 0:
                action = 'new'
            elif is_last_potential_event: # On the last potential event, it could churn or remain active
                action = random.choice(['churn', 'remain_active'])
            else: # Intermediate events
                action = random.choice(['upgrade', 'downgrade', 'churn'])

            current_status = 'active'
            current_end_date_obj = None # Stays None if it's an ongoing active subscription
            prev_plan_id = None  # For track the previous plan in upgrades/downgrades

            if action == 'new':
                # This is the first subscription for the customer
                # It might churn later or remain active indefinitely (represented by None end_date)
                if random.random() < 0.3 and not is_last_potential_event: # 30% chance to churn before max events, if not the very last possible state
                    current_status = 'canceled'
                    current_end_date_obj = potential_end_date_obj
                    active_subscription = False
                elif random.random() < 0.1: # 10% chance to be an ongoing active sub that started in the past
                     current_end_date_obj = None # ongoing active
                else: # Ends at some point, could be past or future if it's the last event
                    current_end_date_obj = potential_end_date_obj
                    if current_end_date_obj > today : # if it's the last event, and active, it can end in future
                         current_end_date_obj = None # make it ongoing active
                    else: # it ended in the past, consider it churned implicitly
                        active_subscription = False # No more events for this one
                        current_status = 'canceled'


            elif action == 'churn':
                current_status = 'canceled'
                current_end_date_obj = potential_end_date_obj
                active_subscription = False
            
            elif action in ['upgrade', 'downgrade']:
                current_status = action + 'd' # 'upgraded' or 'downgraded'
                current_end_date_obj = potential_end_date_obj
                
                # Before adding the current subscription, keep track of its plan_id
                prev_plan_id_for_next = current_plan_id
                
                # Add the current (now ending) subscription
                subscriptions_data.append((
                    customer_id, current_plan_id, 
                    current_start_date_obj.strftime('%Y-%m-%d'), 
                    current_end_date_obj.strftime('%Y-%m-%d') if current_end_date_obj else None, 
                    current_status,
                    None  # No prev_plan for this one as it's the original
                ))
                
                # Setup for the next subscription (the new plan after upgrade/downgrade)
                new_plan_id = random.choice([pid for pid in plan_ids if pid != current_plan_id])
                if not new_plan_id: new_plan_id = random.choice(plan_ids) # Failsafe if only one plan

                current_plan_id = new_plan_id
                current_start_date_obj = current_end_date_obj + timedelta(days=1)
                current_status = 'active' # New subscription is active
                prev_plan_id = prev_plan_id_for_next  # Set previous plan ID for reference
                
                # If this upgrade/downgrade is the last possible event, this new active sub might run indefinitely or churn
                if is_last_potential_event:
                    if random.random() < 0.5: # 50% chance this new active sub churns
                        current_end_date_obj = current_start_date_obj + timedelta(days=random.randint(min_duration, max_duration // 2))
                        if current_end_date_obj > today: current_end_date_obj = today - timedelta(days=random.randint(1,30)) # ensure past if churned
                        current_status = 'canceled'
                        active_subscription = False
                    else: # Remains active
                        current_end_date_obj = None
                # Continue to loop to add this new active subscription in the next iteration's append, or it gets added after loop.
                continue # Skip adding again here, will be added in next iteration or after loop

            else: # remain_active (applies if is_last_potential_event)
                current_status = 'active'
                # 50% chance an active sub at the end of events is ongoing, 50% it has an end_date (could be past or future)
                if random.random() < 0.5 :
                    current_end_date_obj = None
                else:
                    current_end_date_obj = potential_end_date_obj
                    # If it has an end date and it's in the past, it's effectively churned.
                    if current_end_date_obj and current_end_date_obj < today:
                        active_subscription = False # No more events
                        current_status = 'canceled'

            # Add the subscription event
            subscriptions_data.append((
                customer_id, current_plan_id, 
                current_start_date_obj.strftime('%Y-%m-%d'), 
                current_end_date_obj.strftime('%Y-%m-%d') if current_end_date_obj else None, 
                current_status,
                prev_plan_id
            ))

            if not active_subscription: # If churned, break from event loop for this customer
                break
        
        # If after all potential events, the subscription is still marked as active (e.g. from an upgrade/downgrade that became the last event)
        # ensure it's added. This typically covers the case where an upgrade/downgrade was the last action.
        if active_subscription and action not in ['new', 'churn', 'remain_active']: # if the loop ended on an upgrade/downgrade creating a new active sub
            # This new active subscription starts after the previous one ended.
            # It might be ongoing or have a future/past end date.
            final_sub_end_date_obj = None
            if random.random() > 0.3: # 70% chance it's ongoing
                final_sub_end_date_obj = None
            else: # 30% chance it has an end date
                final_sub_end_date_obj = current_start_date_obj + timedelta(days=random.randint(min_duration, max_duration // 2))
                if final_sub_end_date_obj < today: # If it ended in the past
                    current_status = 'canceled'
                # else it ends in the future, status remains active
            
            subscriptions_data.append((
                customer_id, current_plan_id, 
                current_start_date_obj.strftime('%Y-%m-%d'), 
                final_sub_end_date_obj.strftime('%Y-%m-%d') if final_sub_end_date_obj else None, 
                current_status,
                prev_plan_id
            ))

    cursor.executemany(
        "INSERT INTO subscriptions (customer_id, plan_id, start_date, end_date, status, prev_plan_id) VALUES (?, ?, ?, ?, ?, ?)",
        subscriptions_data
    )
    conn.commit()
    print(f"Inserted {len(subscriptions_data)} subscription records.")


def main():
    """Main function to generate all sample data."""
    ensure_db_directory()
    
    # Check if DB exists
    if not os.path.exists(DB_PATH):
        print(f"Database file not found at {DB_PATH}. Please run database_setup.py first.")
        return

    conn = get_db_connection()
    
    try:
        print("Starting data generation...")
        # Generate data in the correct order for foreign key constraints
        plan_ids = create_plans(conn)
        if not plan_ids:
            print("Error: No plans created. Aborting data generation.")
            return

        campaign_ids = create_marketing_campaigns(conn, NUM_CAMPAIGNS)
        # campaign_ids can be empty if NUM_CAMPAIGNS is 0, which is fine

        # Fetch customer id and registration_date together
        customers_info = create_customers(conn, NUM_CUSTOMERS, campaign_ids)
        if not customers_info:
            print("Error: No customers created. Aborting further data generation.")
            return
            
        create_subscriptions(conn, customers_info, plan_ids)
        
        print("Sample data generation complete.")
        
    except sqlite3.Error as e:
        print(f"An SQLite error occurred: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == '__main__':
    main() 