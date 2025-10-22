import React, { useState, useEffect } from "react";
import axios from "axios";
import FulfilmentToggle from "./FulfilmentToggle";
import VariantCard from "./VariantCard";
import AiVariantMappingModal from "./AiVariantMappingModal";
import { SvgIcon } from "../components";

function ProductShowView({
  product,
  store,
  variants,
  variantCount,
  productTypeImages = {},
}) {
  const [productActive, setProductActive] = useState(product.fulfilment_active);
  const [variantStates, setVariantStates] = useState(
    variants.reduce((acc, variant) => {
      acc[variant.id] = variant.fulfilment_active;
      return acc;
    }, {})
  );
  const [isManualProductToggle, setIsManualProductToggle] = useState(false);
  const [aiModalOpen, setAiModalOpen] = useState(false);
  const [variantsData, setVariantsData] = useState(variants);

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

  const handleOpenAiModal = () => {
    setAiModalOpen(true);
  };

  const handleCloseAiModal = () => {
    setAiModalOpen(false);
  };

  const handleAiMappingsCreated = (newMappings) => {
    // Update variants data with new mappings
    setVariantsData((prevVariants) =>
      prevVariants.map((variant) => {
        const newMapping = newMappings.find(
          (m) => m.product_variant_id === variant.id
        );
        if (newMapping) {
          return {
            ...variant,
            variant_mapping: newMapping,
          };
        }
        return variant;
      })
    );
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

  // Check if we have at least one mapped variant
  const hasMappedVariant = variantsData.some((v) => v.variant_mapping);
  const unmappedCount = variantsData.filter((v) => !v.variant_mapping).length;

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
              </span>
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
          {/* AI Auto-Map Button */}
          {hasMappedVariant && unmappedCount > 0 && (
            <div
              className="mb-6 p-4 border border-purple-100 rounded-lg"
              style={{
                backgroundImage:
                  "url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAYAAAAGCAYAAADgzO9IAAAADklEQVR4AWPAAXgHVBAAFvsATyVd4RkAAAAASUVORK5CYII=)",
                backgroundRepeat: "repeat",
              }}
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <h3 className="text-base font-medium text-purple-900 mb-1">
                    <SvgIcon name="ImageMagicIcon" className="w-6 h-6 inline" />{" "}
                    AI Auto-Matching Available
                  </h3>
                  <p className="text-sm text-purple-900">
                    {unmappedCount} variant{unmappedCount !== 1 ? "s" : ""} to
                    set up. Let AI analyze and match the products automatically
                    based on existing ones.
                  </p>
                </div>
                <button
                  onClick={handleOpenAiModal}
                  className="ml-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-purple-600 hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
                >
                  <SvgIcon
                    name="StatusActiveIcon"
                    className="w-5 h-5 inline mr-1"
                  />{" "}
                  Auto-Match Variants
                </button>
              </div>
            </div>
          )}

          <div className="space-y-4">
            {variantsData.map((variant) => (
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
                onMappingChange={handleMappingChange}
                productTypeImages={productTypeImages}
              />
            ))}
          </div>
        </div>
      </div>

      {/* AI Variant Mapping Modal */}
      <AiVariantMappingModal
        isOpen={aiModalOpen}
        onClose={handleCloseAiModal}
        product={product}
        store={store}
        variants={variantsData}
        unmappedCount={unmappedCount}
        onMappingsCreated={handleAiMappingsCreated}
      />
    </div>
  );
}

export default ProductShowView;
