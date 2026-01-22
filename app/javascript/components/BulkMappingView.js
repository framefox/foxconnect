import React, { useState } from "react";
import axios from "axios";
import ProductSelectModal from "./ProductSelectModal";
import SvgIcon from "./SvgIcon";

function BulkMappingView({
  storeUid,
  variantTitles,
  createUrl,
  productTypeImages = {},
}) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedVariantTitle, setSelectedVariantTitle] = useState(null);
  const [isCreating, setIsCreating] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");

  // Filter variant titles based on search query
  const filteredVariantTitles = variantTitles.filter((vt) =>
    vt.title.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const handleBulkAssign = (variantTitle) => {
    setSelectedVariantTitle(variantTitle);
    setIsModalOpen(true);
  };

  const handleProductSelected = async (selection) => {
    if (!selection.product || !selectedVariantTitle) {
      return;
    }

    setIsCreating(true);

    try {
      const response = await axios.post(
        createUrl,
        {
          variant_title: selectedVariantTitle,
          frame_sku: {
            id: selection.product.id,
            code: selection.product.code,
            title: selection.product.title,
            description: selection.product.description,
            cost_cents: selection.product.cost_cents,
            preview_image: selection.product.preview_image,
            long: selection.product.long,
            short: selection.product.short,
            unit: selection.product.unit,
            colour: selection.product.colour,
            country: selection.product.country,
          },
        },
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

      if (response.data.success && response.data.redirect_url) {
        // Redirect to confirmation page
        window.location.href = response.data.redirect_url;
      } else {
        console.error("Bulk mapping failed:", response.data.error);
        alert("Failed to create bulk mappings: " + (response.data.error || "Unknown error"));
      }
    } catch (error) {
      console.error("Error creating bulk mappings:", error);
      alert(
        "Failed to create bulk mappings: " +
          (error.response?.data?.error || error.message)
      );
    } finally {
      setIsCreating(false);
      setIsModalOpen(false);
      setSelectedVariantTitle(null);
    }
  };

  const handleModalClose = () => {
    if (!isCreating) {
      setIsModalOpen(false);
      setSelectedVariantTitle(null);
    }
  };

  return (
    <div className="space-y-6">
      {/* Search and Stats */}
      <div className="bg-white border border-slate-200 rounded-lg p-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-lg font-semibold text-slate-900">
              Variant Titles
            </h2>
            <p className="text-sm text-slate-600">
              {variantTitles.length} unique variant title
              {variantTitles.length !== 1 ? "s" : ""} found across all products
            </p>
          </div>
          <div className="relative">
            <input
              type="text"
              placeholder="Search variant titles..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-64 px-4 py-2 border border-slate-300 rounded-md text-sm focus:ring-2 focus:ring-slate-900 focus:border-slate-900"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery("")}
                className="absolute right-3 top-1/2 transform -translate-y-1/2 text-slate-400 hover:text-slate-600"
              >
                <SvgIcon name="CloseIcon" className="w-4 h-4" />
              </button>
            )}
          </div>
        </div>

        {/* Variant Titles Table */}
        {filteredVariantTitles.length === 0 ? (
          <div className="text-center py-8 text-slate-500">
            {searchQuery
              ? "No variant titles match your search"
              : "No variant titles found in this store"}
          </div>
        ) : (
          <div className="border border-slate-200 rounded-lg overflow-hidden">
            <table className="min-w-full divide-y divide-slate-200">
              <thead className="bg-slate-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                    Variant Title
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                    Total Variants
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-slate-500 uppercase tracking-wider">
                    Action
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-slate-200">
                {filteredVariantTitles.map((vt, index) => (
                  <tr key={index} className="hover:bg-slate-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="text-sm font-medium text-slate-900">
                        {vt.title}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="text-sm text-slate-600">
                        {vt.variant_count} variant
                        {vt.variant_count !== 1 ? "s" : ""}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {vt.mapped_count === vt.variant_count ? (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                          <SvgIcon
                            name="CheckIcon"
                            className="w-3 h-3 mr-1"
                          />
                          All mapped
                        </span>
                      ) : vt.mapped_count > 0 ? (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                          {vt.mapped_count} of {vt.variant_count} mapped
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-600">
                          Not mapped
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right">
                      {vt.unmapped_count > 0 ? (
                        <button
                          onClick={() => handleBulkAssign(vt.title)}
                          disabled={isCreating}
                          className="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md text-white bg-slate-900 hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          <SvgIcon
                            name="PlusCircleIcon"
                            className="w-4 h-4 mr-1"
                          />
                          Bulk Assign ({vt.unmapped_count})
                        </button>
                      ) : (
                        <span className="text-sm text-slate-400">
                          All variants mapped
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Product Select Modal */}
      <ProductSelectModal
        isOpen={isModalOpen}
        onRequestClose={handleModalClose}
        productVariantId={null}
        productVariantTitle={selectedVariantTitle}
        productTypeImages={productTypeImages}
        productOnlyMode={true}
        onProductOnlySelect={handleProductSelected}
        onProductSelect={() => {}}
      />
    </div>
  );
}

export default BulkMappingView;
