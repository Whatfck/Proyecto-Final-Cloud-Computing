import pg8000.native
import os

def check_orders():
    try:
        conn = pg8000.native.Connection(
            user="marketplace_user",
            password="Grupo3Demo2026!",
            host="grupo3-marketplace-db.caj8o0miwa3g.us-east-1.rds.amazonaws.com",
            database="grupo3_marketplace",
            port=5432,
            timeout=10
        )
        res = conn.run("SELECT id, product_name, status, total FROM orders ORDER BY id DESC LIMIT 5")
        for row in res:
            print(f"ID: {row[0]}, Product: {row[1]}, Status: {row[2]}, Total: {row[3]}")
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_orders()
