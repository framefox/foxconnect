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
import ProductSelectionStep from "./components/ProductSelectionStep";
import ArtworkSelectionStep from "./components/ArtworkSelectionStep";
import CropStep from "./components/CropStep";
import Uploader from "./components/Uploader";
import OrderItemCard from "./components/OrderItemCard";
import SubmitProductionButton from "./components/SubmitProductionButton";
import SvgIcon from "./components/SvgIcon";
import ShopifyConnectModal from "./components/ShopifyConnectModal";
import ShopifyConnectButton from "./components/ShopifyConnectButton";
import Lightbox from "./components/Lightbox";
import VideoLightbox from "./components/VideoLightbox";
import VideoGrid from "./components/VideoGrid";
import AccordionSection from "./components/AccordionSection";
import ColorPicker from "./components/ColorPicker";
import WelcomeModal from "./components/WelcomeModal";
import ProductSyncPoller from "./components/ProductSyncPoller";
import EnableBundlesButton from "./components/EnableBundlesButton";
import SyncVariantMockupsButton from "./components/SyncVariantMockupsButton";

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
  ProductSelectionStep,
  ArtworkSelectionStep,
  CropStep,
  Uploader,
  OrderItemCard,
  SubmitProductionButton,
  SvgIcon,
  ShopifyConnectModal,
  ShopifyConnectButton,
  Lightbox,
  VideoLightbox,
  VideoGrid,
  AccordionSection,
  ColorPicker,
  WelcomeModal,
  ProductSyncPoller,
  EnableBundlesButton,
  SyncVariantMockupsButton,
};

// Export components for use in other components
export { SvgIcon, Lightbox };

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
