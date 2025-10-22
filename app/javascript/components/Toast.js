class ToastManager {
  constructor() {
    this.container = null;
    this.toasts = new Map();
    this.init();
  }

  init() {
    // Create toast container
    this.container = document.createElement("div");
    this.container.id = "toast-container";
    this.container.className =
      "fixed top-4 left-1/2 -translate-x-1/2 z-50 space-y-2 pointer-events-none w-80";
    document.body.appendChild(this.container);
  }

  show(message, type = "info", duration = 5000) {
    const toastId = Date.now() + Math.random();
    const toast = this.createToast(message, type, toastId);

    this.container.appendChild(toast);
    this.toasts.set(toastId, toast);

    // Trigger slide-in animation
    requestAnimationFrame(() => {
      toast.classList.remove("-translate-y-full", "opacity-0");
      toast.classList.add("translate-y-0", "opacity-100");
    });

    // Auto-dismiss after duration
    if (duration > 0) {
      setTimeout(() => {
        this.dismiss(toastId);
      }, duration);
    }

    return toastId;
  }

  createToast(message, type, toastId) {
    const toast = document.createElement("div");
    toast.className = `
      transform -translate-y-full opacity-0 transition-all duration-300 ease-in-out
      pointer-events-auto max-w-md w-full bg-white border border-slate-200 rounded-lg shadow-lg
      overflow-hidden hover:shadow-xl
    `
      .trim()
      .replace(/\s+/g, " ");

    const typeConfig = this.getTypeConfig(type);

    toast.innerHTML = `
      <div class="p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <i class="${typeConfig.icon} ${typeConfig.iconColor}"></i>
          </div>
          <div class="ml-3 w-0 flex-1">
            <p class="text-sm font-medium text-slate-900">
              ${this.escapeHtml(message)}
            </p>
          </div>
          <div class="ml-4 flex-shrink-0 flex">
            <button 
              class="inline-flex text-slate-400 hover:text-slate-500 focus:outline-none focus:text-slate-500 transition ease-in-out duration-150"
              onclick="window.toastManager.dismiss(${toastId})"
            >
              <i class="fa-solid fa-times text-sm"></i>
            </button>
          </div>
        </div>
      </div>
      <div class="border-l-4 ${
        typeConfig.borderColor
      } absolute left-0 top-0 bottom-0 w-1"></div>
    `;

    return toast;
  }

  getTypeConfig(type) {
    const configs = {
      success: {
        icon: "fa-solid fa-check-circle",
        iconColor: "text-green-500",
        borderColor: "border-green-500",
      },
      error: {
        icon: "fa-solid fa-exclamation-circle",
        iconColor: "text-red-500",
        borderColor: "border-red-500",
      },
      warning: {
        icon: "fa-solid fa-exclamation-triangle",
        iconColor: "text-yellow-500",
        borderColor: "border-yellow-500",
      },
      info: {
        icon: "fa-solid fa-info-circle",
        iconColor: "text-blue-500",
        borderColor: "border-blue-500",
      },
    };

    return configs[type] || configs.info;
  }

  dismiss(toastId) {
    const toast = this.toasts.get(toastId);
    if (!toast) return;

    // Slide out animation
    toast.classList.remove("translate-y-0", "opacity-100");
    toast.classList.add("-translate-y-full", "opacity-0");

    // Remove from DOM after animation
    setTimeout(() => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast);
      }
      this.toasts.delete(toastId);
    }, 300);
  }

  dismissAll() {
    this.toasts.forEach((toast, toastId) => {
      this.dismiss(toastId);
    });
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }
}

// Initialize toast manager
window.toastManager = new ToastManager();

// Helper functions for Rails flash messages
window.showFlashMessages = function () {
  // Look for flash messages in the DOM and convert them to toasts
  const notices = document.querySelectorAll("[data-flash-notice]");
  const alerts = document.querySelectorAll("[data-flash-alert]");
  const warnings = document.querySelectorAll("[data-flash-warning]");
  const infos = document.querySelectorAll("[data-flash-info]");

  notices.forEach((notice) => {
    const message = notice.getAttribute("data-flash-notice");
    window.toastManager.show(message, "success");
    notice.remove();
  });

  alerts.forEach((alert) => {
    const message = alert.getAttribute("data-flash-alert");
    window.toastManager.show(message, "error");
    alert.remove();
  });

  warnings.forEach((warning) => {
    const message = warning.getAttribute("data-flash-warning");
    window.toastManager.show(message, "warning");
    warning.remove();
  });

  infos.forEach((info) => {
    const message = info.getAttribute("data-flash-info");
    window.toastManager.show(message, "info");
    info.remove();
  });
};

// Auto-show flash messages on page load
document.addEventListener("DOMContentLoaded", window.showFlashMessages);
document.addEventListener("turbo:load", window.showFlashMessages);

export default ToastManager;
