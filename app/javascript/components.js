import React from "react";
import ReactDOM from "react-dom";

// Import all React components
import HelloReact from "./components/HelloReact";
import HelloWorld from "./components/HelloWorld";
import FulfilmentToggle from "./components/FulfilmentToggle";
import VariantFulfilmentToggle from "./components/VariantFulfilmentToggle";
import VariantFulfilmentControl from "./components/VariantFulfilmentControl";
import VariantCard from "./components/VariantCard";
import ProductDetailsView from "./components/ProductDetailsView";
import ProductShowView from "./components/ProductShowView";

// Create a global registry of components
const components = {
  HelloReact,
  HelloWorld,
  FulfilmentToggle,
  VariantFulfilmentToggle,
  VariantFulfilmentControl,
  VariantCard,
  ProductDetailsView,
  ProductShowView,
};

// Auto-mount function
function mountReactComponents() {
  document.querySelectorAll("[data-react-component]").forEach((element) => {
    const componentName = element.dataset.reactComponent;
    const props = JSON.parse(element.dataset.reactProps || "{}");
    const Component = components[componentName];

    if (Component) {
      ReactDOM.render(React.createElement(Component, props), element);
    } else {
      console.warn(`React component "${componentName}" not found`);
    }
  });
}

// Mount on page load and Turbo navigation
document.addEventListener("DOMContentLoaded", mountReactComponents);
document.addEventListener("turbo:load", mountReactComponents);
