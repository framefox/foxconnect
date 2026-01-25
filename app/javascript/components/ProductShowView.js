import React, { useState, useEffect } from "react";
import axios from "axios";
import FulfilmentToggle from "./FulfilmentToggle";
import VariantCard from "./VariantCard";
import { SvgIcon } from "../components";

function ProductShowView({
  product,
  store,
  variants,
  variantCount,
  productTypeImages = {},
  bundleSlotCount = 1,
}) {
  const [productActive, setProductActive] = useState(product.fulfilment_active);
  const [variantStates, setVariantStates] = useState(
    variants.reduce((acc, variant) => {
      acc[variant.id] = variant.fulfilment_active;
      return acc;
    }, {})
  );
  const [isManualProductToggle, setIsManualProductToggle] = useState(false);
  const [variantsData, setVariantsData] = useState(variants);
  const [slotCount, setSlotCount] = useState(bundleSlotCount);
  const [slotCountDropdownOpen, setSlotCountDropdownOpen] = useState(false);
  const [slotCountDropdownPosition, setSlotCountDropdownPosition] = useState({
    top: 0,
    left: 0,
  });
  const [updatingSlotCount, setUpdatingSlotCount] = useState(false);

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
    // NOTE: We intentionally do NOT call the backend here
    // The product toggle endpoint updates ALL variants, which we don't want
    // when auto-syncing the product state based on individual variant changes.
    // The product state in the UI is just a visual indicator.
    console.log(`Product fulfilment state updated to ${isActive} (UI only, no backend call)`);
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
            `/connections/stores/${store.uid}/product_variants/${variant.id}/set_fulfilment?active=${newState}`,
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

  const handleMappingChange = (variantId, newMapping) => {
    // Update the specific variant's mapping in the state
    setVariantsData((prevVariants) =>
      prevVariants.map((variant) =>
        variant.id === variantId
          ? { ...variant, variant_mapping: newMapping }
          : variant
      )
    );
  };

  const handleUpdateSlotCount = async (newSlotCount) => {
    if (newSlotCount === slotCount) {
      return;
    }

    // Confirm if reducing slots
    if (newSlotCount < slotCount) {
      if (
        !confirm(
          `This will remove slots ${newSlotCount + 1}-${slotCount} and their configurations from all variants. Continue?`
        )
      ) {
        return;
      }
    }

    setUpdatingSlotCount(true);

    try {
      const response = await axios.patch(
        `/connections/stores/${store.uid}/products/${product.id}/update_bundle_slot_count`,
        { slot_count: newSlotCount },
        {
          headers: {
            "Content-Type": "application/json",
            "X-Requested-With": "XMLHttpRequest",
            "X-CSRF-Token": document
              .querySelector('meta[name="csrf-token"]')
              .getAttribute("content"),
          },
        }
      );

      if (response.data.success) {
        // Reload page to reflect new bundle configuration
        window.location.reload();
      } else {
        alert(`Error: ${response.data.error}`);
      }
    } catch (error) {
      alert(
        `Failed to update bundle size: ${
          error.response?.data?.error || error.message
        }`
      );
    } finally {
      setUpdatingSlotCount(false);
    }
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
              <span>
                External ID:{" "}
                {!product.platform_url ? (
                  product.external_id
                ) : (
                  <a
                    href={product.platform_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-600 hover:text-blue-800 hover:underline"
                  >
                    {product.external_id}
                    <SvgIcon
                      name="ExternalSmallIcon"
                      className="w-4.5 h-4.5 inline"
                    />
                  </a>
                )}
              </span>
            </div>
          </div>
        </div>

        <div className="flex items-center ml-8">
          <FulfilmentToggle
            productId={product.id}
            storeId={store.uid}
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
                <SvgIcon
                  name="ImageIcon"
                  className="w-8 h-8 text-slate-400 mx-auto"
                />
                <p className="text-sm text-slate-500">No image available</p>
              </div>
            )}
          </div>
        </div>

        {/* Variants Section (2/3) */}
        <div className="lg:col-span-2">
          <div className="space-y-4">
            {/* Bundle Size Panel - only show when bundles are enabled */}
            {product.bundles_enabled && (
              <div className="bg-white border border-slate-200 rounded-lg p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="text-sm font-medium text-slate-900">Bundle Configuration</h3>
                    <p className="text-xs text-slate-500 mt-0.5">
                      Set the number of items in each bundle
                    </p>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className="text-sm text-slate-600">Bundle size:</span>
                    <div className="relative">
                      <button
                        onClick={(e) => {
                          const rect = e.currentTarget.getBoundingClientRect();
                          setSlotCountDropdownPosition({
                            top: rect.bottom + window.scrollY + 4,
                            left: rect.left + window.scrollX,
                          });
                          setSlotCountDropdownOpen(!slotCountDropdownOpen);
                        }}
                        disabled={updatingSlotCount}
                        className="inline-flex items-center px-3 py-1.5 text-sm font-medium rounded-md bg-slate-100 text-slate-700 hover:bg-slate-200 transition-colors disabled:opacity-50"
                      >
                        {slotCount} {slotCount === 1 ? "item" : "items"}
                        <i className="fa-solid fa-chevron-down ml-2 text-xs"></i>
                      </button>

                      {slotCountDropdownOpen && (
                        <>
                          <div
                            className="fixed inset-0 z-40"
                            onClick={() => setSlotCountDropdownOpen(false)}
                          />
                          <div
                            className="fixed w-32 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 z-50"
                            style={{
                              top: `${slotCountDropdownPosition.top}px`,
                              left: `${slotCountDropdownPosition.left}px`,
                            }}
                          >
                            <div className="py-1 max-h-64 overflow-y-auto">
                              {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((count) => (
                                <button
                                  key={count}
                                  onClick={() => {
                                    setSlotCountDropdownOpen(false);
                                    handleUpdateSlotCount(count);
                                  }}
                                  className={`block w-full text-left px-4 py-2 text-sm ${
                                    count === slotCount
                                      ? "bg-slate-100 text-slate-900 font-medium"
                                      : "text-slate-700 hover:bg-slate-50"
                                  }`}
                                >
                                  {count} {count === 1 ? "item" : "items"}
                                </button>
                              ))}
                            </div>
                          </div>
                        </>
                      )}
                    </div>
                    {updatingSlotCount && (
                      <i className="fa-solid fa-spinner-third fa-spin text-slate-400 text-sm"></i>
                    )}
                  </div>
                </div>
              </div>
            )}

            {variantsData.map((variant) => (
              <VariantCard
                key={variant.id}
                variant={{
                  id: variant.id,
                  title: variant.title,
                  external_variant_id: variant.external_variant_id,
                  fulfilment_active: variantStates[variant.id],
                  variant_mapping: variant.variant_mapping,
                  bundle: variant.bundle,
                }}
                storeId={store.uid}
                storePlatform={store.platform}
                onToggle={handleVariantToggle}
                onMappingChange={handleMappingChange}
                productTypeImages={productTypeImages}
                bundlesEnabled={product.bundles_enabled}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

export default ProductShowView;
