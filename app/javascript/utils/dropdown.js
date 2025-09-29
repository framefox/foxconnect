// Global dropdown utility for vanilla JS dropdowns
// Handles click outside, toggle functionality, and proper ARIA attributes

class DropdownManager {
  constructor() {
    this.activeDropdown = null;
    this.init();
  }

  init() {
    // Close dropdown when clicking outside
    document.addEventListener("click", (e) => {
      if (this.activeDropdown && !this.activeDropdown.contains(e.target)) {
        this.closeActiveDropdown();
      }
    });

    // Close dropdown on escape key
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && this.activeDropdown) {
        this.closeActiveDropdown();
      }
    });

    // Initialize all dropdowns on page load
    this.initializeDropdowns();
  }

  initializeDropdowns() {
    document.querySelectorAll("[data-dropdown]").forEach((dropdown) => {
      this.setupDropdown(dropdown);
    });
  }

  setupDropdown(dropdown) {
    const trigger = dropdown.querySelector("[data-dropdown-trigger]");
    const menu = dropdown.querySelector("[data-dropdown-menu]");

    if (!trigger || !menu) return;

    // Set initial ARIA attributes
    const menuId = `dropdown-menu-${Math.random().toString(36).substr(2, 9)}`;
    menu.id = menuId;
    trigger.setAttribute("aria-haspopup", "true");
    trigger.setAttribute("aria-expanded", "false");
    trigger.setAttribute("aria-controls", menuId);
    menu.setAttribute("role", "menu");
    menu.setAttribute("aria-hidden", "true");

    // Handle trigger click
    trigger.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();

      const isOpen = trigger.getAttribute("aria-expanded") === "true";

      if (isOpen) {
        this.closeDropdown(dropdown);
      } else {
        this.closeActiveDropdown(); // Close any other open dropdowns
        this.openDropdown(dropdown);
      }
    });

    // Handle menu item clicks
    menu.querySelectorAll('[role="menuitem"]').forEach((item) => {
      item.setAttribute("tabindex", "-1");
    });
  }

  openDropdown(dropdown) {
    const trigger = dropdown.querySelector("[data-dropdown-trigger]");
    const menu = dropdown.querySelector("[data-dropdown-menu]");

    trigger.setAttribute("aria-expanded", "true");
    menu.setAttribute("aria-hidden", "false");
    menu.classList.remove("hidden");
    menu.classList.add("block");

    this.activeDropdown = dropdown;
  }

  closeDropdown(dropdown) {
    const trigger = dropdown.querySelector("[data-dropdown-trigger]");
    const menu = dropdown.querySelector("[data-dropdown-menu]");

    trigger.setAttribute("aria-expanded", "false");
    menu.setAttribute("aria-hidden", "true");
    menu.classList.remove("block");
    menu.classList.add("hidden");

    if (this.activeDropdown === dropdown) {
      this.activeDropdown = null;
    }
  }

  closeActiveDropdown() {
    if (this.activeDropdown) {
      this.closeDropdown(this.activeDropdown);
    }
  }

  // Reinitialize dropdowns after dynamic content is added
  reinitialize() {
    this.initializeDropdowns();
  }
}

// Initialize dropdown manager when DOM is ready
document.addEventListener("DOMContentLoaded", () => {
  window.dropdownManager = new DropdownManager();
});

// Also initialize on Turbo page loads (for SPA-like navigation)
document.addEventListener("turbo:load", () => {
  if (window.dropdownManager) {
    window.dropdownManager.initializeDropdowns();
  } else {
    window.dropdownManager = new DropdownManager();
  }
});

export default DropdownManager;
