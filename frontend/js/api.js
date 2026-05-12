// API client para comunicarse con el backend Express
const API_BASE_URL = window.location.origin;

const api = {
  async getProducts() {
    try {
      const res = await fetch(`${API_BASE_URL}/api/products`);
      return await res.json();
    } catch (error) {
      console.error('Error fetching products:', error);
      return [];
    }
  },

  async createProduct(product) {
    try {
      const res = await fetch(`${API_BASE_URL}/api/products`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(product),
      });
      return await res.json();
    } catch (error) {
      console.error('Error creating product:', error);
      return { error: error.message };
    }
  },

  async getOrders() {
    try {
      const res = await fetch(`${API_BASE_URL}/api/orders`);
      return await res.json();
    } catch (error) {
      console.error('Error fetching orders:', error);
      return [];
    }
  },

  async createOrder(order) {
    const API_GATEWAY_URL = 'https://dkooiiy388.execute-api.us-east-1.amazonaws.com';
    try {
      const res = await fetch(`${API_GATEWAY_URL}/api/orders`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(order),
      });
      return await res.json();
    } catch (error) {
      console.error('Error creating order via API Gateway:', error);
      return { error: error.message };
    }
  },
};
