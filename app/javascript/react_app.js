import React from "react";
import { createRoot } from "react-dom";

// Import your React components here
import HelloReact from "./components/HelloReact";
import HelloWorld from "./components/HelloWorld";

// Function to mount React components
function mountReactComponents() {
  // Find all elements with data-react-component attribute
  const reactElements = document.querySelectorAll("[data-react-component]");

  reactElements.forEach((element) => {
    const componentName = element.dataset.reactComponent;
    const props = JSON.parse(element.dataset.reactProps || "{}");

    let Component;
    switch (componentName) {
      case "HelloReact":
        Component = HelloReact;
        break;
      case "HelloWorld":
        Component = HelloWorld;
        break;
      default:
        console.warn(`Unknown React component: ${componentName}`);
        return;
    }

    if (Component) {
      const root = createRoot(element);
      root.render(React.createElement(Component, props));
    }
  });
}

// Mount components when DOM is loaded
document.addEventListener("DOMContentLoaded", mountReactComponents);

// Mount components when navigating with Turbo (for SPA-like navigation)
document.addEventListener("turbo:load", mountReactComponents);

export { mountReactComponents };
