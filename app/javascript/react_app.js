import React from "react";
import ReactDOM from "react-dom";

// Import your React components here
import HelloReact from "components/HelloReact";
import HelloWorld from "components/HelloWorld";
import FulfilmentToggle from "components/FulfilmentToggle";

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
      case "FulfilmentToggle":
        Component = FulfilmentToggle;
        break;
      default:
        console.warn(`Unknown React component: ${componentName}`);
        return;
    }

    if (Component) {
      // React 18 should have the render method available
      ReactDOM.render(React.createElement(Component, props), element);
    }
  });
}

// Mount components when DOM is loaded
document.addEventListener("DOMContentLoaded", mountReactComponents);

// Mount components when navigating with Turbo (for SPA-like navigation)
document.addEventListener("turbo:load", mountReactComponents);

export { mountReactComponents };
