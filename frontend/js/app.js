const { createApp } = Vue;

createApp({
  data() {
    return {
      currentPage: 'products',
      products: [],
      orders: [],
      selectedProduct: null,
      formProduct: {
        name: '',
        description: '',
        price: 0,
        stock: 0,
      },
      productImage: null,
      orderData: {
        quantity: 1,
        buyerName: '',
        buyerEmail: '',
      },
      message: '',
      messageClass: 'alert-info',
    };
  },
  mounted() {
    this.loadProducts();
    this.loadOrders();
  },
  methods: {
    onImageSelected(event) {
      this.productImage = event.target.files[0];
    },
    async loadProducts() {
      this.products = await api.getProducts();
    },
    async loadOrders() {
      this.orders = await api.getOrders();
    },
    async createProduct() {
      const formData = new FormData();
      formData.append('name', this.formProduct.name);
      formData.append('description', this.formProduct.description);
      formData.append('price', this.formProduct.price);
      formData.append('stock', this.formProduct.stock);
      if (this.productImage) {
        formData.append('image', this.productImage);
      }

      try {
        const res = await fetch(`${API_BASE_URL}/api/products`, {
          method: 'POST',
          body: formData,
        });
        const result = await res.json();
        
        if (result.error) {
          this.message = `Error: ${result.error}`;
          this.messageClass = 'alert-danger';
        } else {
          this.message = 'Producto creado exitosamente!';
          this.messageClass = 'alert-success';
          this.formProduct = { name: '', description: '', price: 0, stock: 0 };
          this.productImage = null;
          setTimeout(() => {
            this.message = '';
            this.currentPage = 'products';
            this.loadProducts();
          }, 2000);
        }
      } catch (error) {
        this.message = `Error: ${error.message}`;
        this.messageClass = 'alert-danger';
      }
    },
    selectProduct(product) {
      this.selectedProduct = product;
      this.currentPage = 'orders';
      this.orderData = { quantity: 1, buyerName: '', buyerEmail: '' };
    },
    async createOrder() {
      const order = {
        productId: this.selectedProduct.id,
        productName: this.selectedProduct.name,
        quantity: this.orderData.quantity,
        total: this.selectedProduct.price * this.orderData.quantity,
        buyerName: this.orderData.buyerName,
        buyerEmail: this.orderData.buyerEmail,
      };
      const result = await api.createOrder(order);
      if (result.error) {
        this.message = `Error: ${result.error}`;
        this.messageClass = 'alert-danger';
      } else {
        this.message = 'Orden creada! Se enviará al procesamiento.';
        this.messageClass = 'alert-success';
        setTimeout(() => {
          this.selectedProduct = null;
          this.loadOrders();
          this.loadProducts();
        }, 2000);
      }
    },
    getStatusClass(status) {
      const classes = {
        'PENDING': 'badge bg-warning',
        'PROCESSING': 'badge bg-info',
        'COMPLETED': 'badge bg-success',
        'FAILED': 'badge bg-danger',
      };
      return classes[status] || 'badge bg-secondary';
    },
  },
}).mount('#app');
