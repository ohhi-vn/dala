const DesignCanvas = {
  mounted() {
    this.canvas = this.el;
    this.setupDropZone();
    this.makeNodesDraggable();
  },

  setupDropZone() {
    this.canvas.addEventListener('dragover', (e) => this.handleDragOver(e));
    this.canvas.addEventListener('drop', (e) => this.handleDrop(e));
  },

  handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'copy';
    this.canvas.classList.add('drop-zone-active');
  },

  handleDrop(e) {
    e.preventDefault();
    this.canvas.classList.remove('drop-zone-active');

    const rect = this.canvas.getBoundingClientRect();
    const zoom = parseFloat(this.canvas.dataset.zoom || '1');
    const gridSnap = this.canvas.dataset.snapToGrid === 'true';
    const gridSize = parseInt(this.canvas.dataset.gridSize || '8', 10);

    let x = (e.clientX - rect.left) / zoom;
    let y = (e.clientY - rect.top) / zoom;

    if (gridSnap) {
      x = Math.round(x / gridSize) * gridSize;
      y = Math.round(y / gridSize) * gridSize;
    }

    const componentType = e.dataTransfer.getData('component');
    if (componentType) {
      this.pushEvent('drop_component', { type: componentType, x: x, y: y });
    }
  },

  makeNodesDraggable() {
    const nodes = this.canvas.querySelectorAll('[data-node-id]');
    nodes.forEach(node => {
      node.addEventListener('mousedown', (e) => this.startNodeDrag(e, node));
    });
  },

  startNodeDrag(e, node) {
    e.preventDefault();
    const startX = e.clientX;
    const startY = e.clientY;
    const nodeId = node.dataset.nodeId;
    const zoom = parseFloat(this.canvas.dataset.zoom || '1');
    const gridSnap = this.canvas.dataset.snapToGrid === 'true';
    const gridSize = parseInt(this.canvas.dataset.gridSize || '8', 10);

    const nodeRect = node.getBoundingClientRect();
    const canvasRect = this.canvas.getBoundingClientRect();

    const initialX = (nodeRect.left - canvasRect.left) / zoom;
    const initialY = (nodeRect.top - canvasRect.top) / zoom;

    const onMouseMove = (e) => {
      let newX = initialX + (e.clientX - startX) / zoom;
      let newY = initialY + (e.clientY - startY) / zoom;

      if (gridSnap) {
        newX = Math.round(newX / gridSize) * gridSize;
        newY = Math.round(newY / gridSize) * gridSize;
      }

      node.style.left = newX + 'px';
      node.style.top = newY + 'px';
    };

    const onMouseUp = () => {
      document.removeEventListener('mousemove', onMouseMove);
      document.removeEventListener('mouseup', onMouseUp);

      const finalX = parseFloat(node.style.left);
      const finalY = parseFloat(node.style.top);

      this.pushEvent('move_node', { id: nodeId, x: finalX, y: finalY });
    };

    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);
  }
};

export default DesignCanvas;
