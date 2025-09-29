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
                  className="w-16 h-16 text-slate-400 mx-auto"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2 2v12a2 2 0 002 2z"
                  />
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
