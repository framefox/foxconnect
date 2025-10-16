import React, { useState, useEffect } from "react";
import axios from "axios";
import FulfilmentToggle from "./FulfilmentToggle";
import VariantCard from "./VariantCard";

function ProductShowView({ product, store, variants, variantCount }) {
  const [productActive, setProductActive] = useState(product.fulfilment_active);
  const [variantStates, setVariantStates] = useState(
    variants.reduce((acc, variant) => {
      acc[variant.id] = variant.fulfilment_active;
      return acc;
    }, {})
  );
  const [isManualProductToggle, setIsManualProductToggle] = useState(false);

  const activeVariants = Object.values(variantStates).filter(Boolean).length;

  // Update product toggle when variant states change (but not during manual product toggles)
  useEffect(() => {
    if (isManualProductToggle) {
      // Reset the flag after manual toggle is processed
      setIsManualProductToggle(false);
      return;
    }

    const shouldProductBeActive = activeVariants > 0;
    if (shouldProductBeActive !== productActive) {
      console.log(
        `Auto-updating product toggle: ${productActive} -> ${shouldProductBeActive} (due to variant changes)`
      );
      setProductActive(shouldProductBeActive);
      // Update product on server when auto-toggling due to variant changes
      updateProductFulfilment(shouldProductBeActive);
    }
  }, [activeVariants, productActive, isManualProductToggle]);

  const updateProductFulfilment = async (isActive) => {
    try {
      await axios.patch(
        `/connections/stores/${store.id}/products/${product.id}/toggle_fulfilment`,
        {},
        {
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": document
              .querySelector('meta[name="csrf-token"]')
              .getAttribute("content"),
          },
        }
      );
    } catch (error) {
      console.error(
        "Error updating product fulfilment:",
        error.response?.data || error.message
      );
    }
  };

  const handleProductToggle = async (newState) => {
    console.log(
      `Manual product toggle clicked: ${productActive} -> ${newState}`
    );

    // Set flag to prevent auto-toggle during manual operation
    setIsManualProductToggle(true);
    setProductActive(newState);

    // Update all variants to match product state
    const newVariantStates = {};
    variants.forEach((variant) => {
      newVariantStates[variant.id] = newState;
    });
    setVariantStates(newVariantStates);

    // Update product on server first
    try {
      await updateProductFulfilment(newState);
      console.log(`Product updated on server: ${newState}`);
    } catch (error) {
      console.error("Error updating product:", error);
    }

    // Update all variants on server to specific state
    try {
      console.log(`Setting ${variants.length} variants to: ${newState}`);
      const variantUpdates = await Promise.all(
        variants.map((variant) =>
          axios.patch(
            `/connections/stores/${store.id}/product_variants/${variant.id}/set_fulfilment?active=${newState}`,
            {},
            {
              headers: {
                "Content-Type": "application/json",
                "X-CSRF-Token": document
                  .querySelector('meta[name="csrf-token"]')
                  .getAttribute("content"),
              },
            }
          )
        )
      );
      console.log(
        `All ${variantUpdates.length} variants set to ${newState} successfully`
      );
    } catch (error) {
      console.error(
        "Error setting variant fulfilment:",
        error.response?.data || error.message
      );
    }
  };

  const handleVariantToggle = (variantId, newState) => {
    setVariantStates((prev) => ({
      ...prev,
      [variantId]: newState,
    }));
  };

  return (
    <div className="space-y-8">
      {/* Product Header */}
      <div className="flex items-start justify-between">
        <div className="space-y-4 flex-1">
          <div className="space-y-2">
            <h1 className="scroll-m-20 text-3xl font-semibold tracking-tight text-slate-900">
              {product.title}
            </h1>
            <div className="flex items-center space-x-4 text-sm text-slate-600">
              <span>External ID: {product.external_id}</span>
              <span>•</span>
              <span>Handle: {product.handle}</span>
            </div>
          </div>
        </div>

        <div className="flex items-center space-x-4 ml-8">
          <FulfilmentToggle
            productId={product.id}
            storeId={store.id}
            initialActive={productActive}
            activeVariants={activeVariants}
            totalVariants={variantCount}
            onToggle={handleProductToggle}
          />
        </div>
      </div>

      {/* Product Details Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Product Image & Metadata (1/3) */}
        <div className="space-y-4">
          <div className="aspect-square bg-slate-50 rounded-lg border border-slate-200 flex items-center justify-center">
            {product.featured_image_url ? (
              <img
                src={product.featured_image_url}
                alt={product.title}
                className="w-full h-full object-cover rounded-lg"
              />
            ) : (
              <div className="text-center space-y-2">
                <svg
                  viewBox="0 0 20 20"
                  className="w-8 h-8 text-slate-400 mx-auto"
                >
                  <path
                    fill="currentColor"
                    d="M12.5 9a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z"
                  ></path>
                  <path
                    fill="currentColor"
                    fillRule="evenodd"
                    d="M9.018 3.5h1.964c.813 0 1.469 0 2 .043.546.045 1.026.14 1.47.366a3.75 3.75 0 0 1 1.64 1.639c.226.444.32.924.365 1.47.043.531.043 1.187.043 2v1.964c0 .813 0 1.469-.043 2-.045.546-.14 1.026-.366 1.47a3.75 3.75 0 0 1-1.639 1.64c-.444.226-.924.32-1.47.365-.531.043-1.187.043-2 .043h-1.964c-.813 0-1.469 0-2-.043-.546-.045-1.026-.14-1.47-.366a3.75 3.75 0 0 1-1.64-1.639c-.226-.444-.32-.924-.365-1.47-.043-.531-.043-1.187-.043-2v-1.964c0-.813 0-1.469.043-2 .045-.546.14-1.026.366-1.47a3.75 3.75 0 0 1 1.639-1.64c.444-.226.924-.32 1.47-.365.531-.043 1.187-.043 2-.043Zm-1.877 1.538c-.454.037-.715.107-.912.207a2.25 2.25 0 0 0-.984.984c-.1.197-.17.458-.207.912-.037.462-.038 1.057-.038 1.909v1.428l.723-.867a1.75 1.75 0 0 1 2.582-.117l2.695 2.695 1.18-1.18a1.75 1.75 0 0 1 2.604.145l.216.27v-2.374c0-.852 0-1.447-.038-1.91-.037-.453-.107-.714-.207-.911a2.25 2.25 0 0 0-.984-.984c-.197-.1-.458-.17-.912-.207-.462-.037-1.056-.038-1.909-.038h-1.9c-.852 0-1.447 0-1.91.038Zm-2.103 7.821a7.12 7.12 0 0 1-.006-.08.746.746 0 0 0 .044-.049l1.8-2.159a.25.25 0 0 1 .368-.016l3.226 3.225a.75.75 0 0 0 1.06 0l1.71-1.71a.25.25 0 0 1 .372.021l1.213 1.516c-.021.06-.045.114-.07.165-.216.423-.56.767-.984.983-.197.1-.458.17-.912.207-.462.037-1.056.038-1.909.038h-1.9c-.852 0-1.447 0-1.91-.038-.453-.037-.714-.107-.911-.207a2.25 2.25 0 0 1-.984-.984c-.1-.197-.17-.458-.207-.912Z"
                  ></path>
                </svg>
                <p className="text-sm text-slate-500">No image available</p>
              </div>
            )}
          </div>
        </div>

        {/* Variants Section (2/3) */}
        <div className="lg:col-span-2">
          <div className="space-y-4">
            {variants.map((variant) => (
              <VariantCard
                key={variant.id}
                variant={{
                  id: variant.id,
                  title: variant.title,
                  external_variant_id: variant.external_variant_id,
                  fulfilment_active: variantStates[variant.id],
                  variant_mapping: variant.variant_mapping,
                }}
                storeId={store.id}
                onToggle={handleVariantToggle}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

export default ProductShowView;
