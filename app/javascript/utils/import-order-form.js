// Import Order Form - Platform-specific help text
document.addEventListener('DOMContentLoaded', () => {
  const form = document.querySelector('[data-import-order-form]');
  if (!form) return;

  const storeSelect = form.querySelector('select[name="store_id"]');
  const orderIdInput = form.querySelector('[data-order-id-input]');
  const orderIdHelp = form.querySelector('[data-order-id-help]');
  const shopifyHelp = form.querySelector('[data-shopify-help]');
  const squarespaceHelp = form.querySelector('[data-squarespace-help]');

  function updatePlatform() {
    const selectedOption = storeSelect.options[storeSelect.selectedIndex];
    const platform = selectedOption.getAttribute('data-platform');

    if (platform === 'shopify') {
      showShopify();
    } else if (platform === 'squarespace') {
      showSquarespace();
    }
  }

  function showShopify() {
    // Update placeholder
    if (orderIdInput) {
      orderIdInput.placeholder = 'e.g., 6592019005730';
    }

    // Update help text
    if (orderIdHelp) {
      orderIdHelp.textContent = 'Enter the numeric Order ID from your Shopify admin order URL.';
    }

    // Show Shopify help, hide Squarespace help
    if (shopifyHelp) {
      shopifyHelp.classList.remove('hidden');
    }
    if (squarespaceHelp) {
      squarespaceHelp.classList.add('hidden');
    }
  }

  function showSquarespace() {
    // Update placeholder
    if (orderIdInput) {
      orderIdInput.placeholder = 'e.g., 585d498fdee9f31a60284a37';
    }

    // Update help text
    if (orderIdHelp) {
      orderIdHelp.textContent = 'Enter the alphanumeric Order ID from your Squarespace order URL.';
    }

    // Show Squarespace help, hide Shopify help
    if (shopifyHelp) {
      shopifyHelp.classList.add('hidden');
    }
    if (squarespaceHelp) {
      squarespaceHelp.classList.remove('hidden');
    }
  }

  // Set initial state
  if (storeSelect) {
    updatePlatform();
    storeSelect.addEventListener('change', updatePlatform);
  }
});

