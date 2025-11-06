// Product Options Manager for dynamic option/value inputs
// Handles adding/removing product options and their values

class ProductOptionsManager {
  constructor() {
    this.optionIndex = 0;
    this.maxOptions = 3;
    this.init();
  }

  init() {
    // Initialize on page load
    this.initializeProductOptions();
  }

  initializeProductOptions() {
    const containers = document.querySelectorAll('[data-controller="product-options"]');
    
    containers.forEach((container) => {
      this.setupProductOptions(container);
    });
  }

  setupProductOptions(container) {
    const addOptionBtn = container.querySelector('[data-action="product-options#addOption"]');
    const optionsContainer = container.querySelector('[data-product-options-target="optionsContainer"]');
    const emptyState = container.querySelector('[data-product-options-target="emptyState"]');
    const optionTemplate = container.querySelector('[data-product-options-target="optionTemplate"]');
    const valueTemplate = container.querySelector('[data-product-options-target="valueTemplate"]');

    if (!addOptionBtn || !optionsContainer || !optionTemplate) {
      console.error("Product options setup failed: missing required elements");
      return;
    }

    // Store references
    container._optionsManager = {
      optionIndex: 0,
      valueIndexes: {},
      optionsContainer,
      emptyState,
      optionTemplate,
      valueTemplate,
      maxOptions: parseInt(addOptionBtn.dataset.productOptionsMaxParam) || 3
    };

    // Add first option by default
    this.addOption(container);

    // Setup add option button
    addOptionBtn.addEventListener('click', (e) => {
      e.preventDefault();
      this.addOption(container);
    });

    // Setup remove handlers (delegated)
    optionsContainer.addEventListener('click', (e) => {
      // Handle remove option
      if (e.target.closest('[data-action="product-options#removeOption"]')) {
        e.preventDefault();
        const btn = e.target.closest('[data-action="product-options#removeOption"]');
        const optionIndex = btn.dataset.optionIndex;
        this.removeOption(container, optionIndex);
      }

      // Handle add value
      if (e.target.closest('[data-action="product-options#addValue"]')) {
        e.preventDefault();
        const btn = e.target.closest('[data-action="product-options#addValue"]');
        const optionIndex = btn.dataset.optionIndex;
        this.addValue(container, optionIndex);
      }

      // Handle remove value
      if (e.target.closest('[data-action="product-options#removeValue"]')) {
        e.preventDefault();
        const btn = e.target.closest('[data-action="product-options#removeValue"]');
        const optionIndex = btn.dataset.optionIndex;
        const valueIndex = btn.dataset.valueIndex;
        this.removeValue(container, optionIndex, valueIndex);
      }
    });
  }

  addOption(container) {
    const manager = container._optionsManager;
    // Only count option elements that are direct children of the container (not in templates)
    const currentCount = manager.optionsContainer.querySelectorAll(':scope > [data-option-index]').length;

    if (currentCount >= manager.maxOptions) {
      alert(`Maximum ${manager.maxOptions} options allowed`);
      return;
    }

    const optionIndex = manager.optionIndex++;
    const optionNumber = currentCount + 1;

    // Clone template
    const template = manager.optionTemplate.content.cloneNode(true);
    const optionElement = template.querySelector('[data-option-index]');

    // Replace placeholders
    const html = optionElement.innerHTML
      .replace(/__INDEX__/g, optionIndex)
      .replace(/__NUMBER__/g, optionNumber);
    optionElement.innerHTML = html;
    optionElement.dataset.optionIndex = optionIndex;

    // Update data attributes
    const removeBtn = optionElement.querySelector('[data-action="product-options#removeOption"]');
    if (removeBtn) {
      removeBtn.dataset.optionIndex = optionIndex;
    }

    const addValueBtn = optionElement.querySelector('[data-action="product-options#addValue"]');
    if (addValueBtn) {
      addValueBtn.dataset.optionIndex = optionIndex;
    }

    // Initialize value index counter for this option
    manager.valueIndexes[optionIndex] = 1; // Start at 1 since template has 0

    // Append to container
    manager.optionsContainer.appendChild(optionElement);

    // Hide empty state
    if (manager.emptyState) {
      manager.emptyState.classList.add('hidden');
    }
  }

  removeOption(container, optionIndex) {
    const manager = container._optionsManager;
    const optionElement = manager.optionsContainer.querySelector(`:scope > [data-option-index="${optionIndex}"]`);
    
    if (optionElement) {
      optionElement.remove();
      delete manager.valueIndexes[optionIndex];

      // Show empty state if no options left
      const remainingOptions = manager.optionsContainer.querySelectorAll(':scope > [data-option-index]');
      if (remainingOptions.length === 0 && manager.emptyState) {
        manager.emptyState.classList.remove('hidden');
      }

      // Renumber remaining options
      this.renumberOptions(container);
    }
  }

  addValue(container, optionIndex) {
    const manager = container._optionsManager;
    const optionElement = manager.optionsContainer.querySelector(`[data-option-index="${optionIndex}"]`);
    
    if (!optionElement) return;

    const valuesContainer = optionElement.querySelector(`[data-values-container="${optionIndex}"]`);
    if (!valuesContainer) return;

    // Get next value index
    if (!manager.valueIndexes[optionIndex]) {
      manager.valueIndexes[optionIndex] = 0;
    }
    const valueIndex = manager.valueIndexes[optionIndex]++;

    // Clone value template
    const template = manager.valueTemplate.content.cloneNode(true);
    const valueElement = template.querySelector('[data-value-index]');

    // Replace placeholders
    const html = valueElement.innerHTML
      .replace(/__OPTION_INDEX__/g, optionIndex)
      .replace(/__VALUE_INDEX__/g, valueIndex);
    valueElement.innerHTML = html;
    valueElement.dataset.valueIndex = valueIndex;

    // Update data attributes on buttons
    const removeBtn = valueElement.querySelector('[data-action="product-options#removeValue"]');
    if (removeBtn) {
      removeBtn.dataset.optionIndex = optionIndex;
      removeBtn.dataset.valueIndex = valueIndex;
    }

    valuesContainer.appendChild(valueElement);
  }

  removeValue(container, optionIndex, valueIndex) {
    const manager = container._optionsManager;
    const optionElement = manager.optionsContainer.querySelector(`[data-option-index="${optionIndex}"]`);
    
    if (!optionElement) return;

    const valuesContainer = optionElement.querySelector(`[data-values-container="${optionIndex}"]`);
    if (!valuesContainer) return;

    const valueElements = valuesContainer.querySelectorAll('[data-value-index]');
    
    // Don't allow removing if it's the last value
    if (valueElements.length <= 1) {
      alert('Each option must have at least one value');
      return;
    }

    const valueElement = valuesContainer.querySelector(`[data-value-index="${valueIndex}"]`);
    if (valueElement) {
      valueElement.remove();
    }
  }

  renumberOptions(container) {
    const manager = container._optionsManager;
    const options = manager.optionsContainer.querySelectorAll(':scope > [data-option-index]');
    
    options.forEach((option, index) => {
      const heading = option.querySelector('h3');
      if (heading) {
        heading.textContent = `Option ${index + 1}`;
      }
    });
  }

  // Reinitialize after dynamic content is added
  reinitialize() {
    this.initializeProductOptions();
  }
}

// Initialize manager when DOM is ready
document.addEventListener("DOMContentLoaded", () => {
  window.productOptionsManager = new ProductOptionsManager();
});

// Also initialize on Turbo page loads (for SPA-like navigation)
document.addEventListener("turbo:load", () => {
  if (window.productOptionsManager) {
    window.productOptionsManager.initializeProductOptions();
  } else {
    window.productOptionsManager = new ProductOptionsManager();
  }
});

export default ProductOptionsManager;

