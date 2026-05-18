import React, { useState } from "react";
import axios from "axios";
import ProductSelectModal from "./ProductSelectModal";
import SvgIcon from "./SvgIcon";

const mappingStatusFilters = [
  { value: "not_mapped", label: "Not Mapped" },
  { value: "partially_mapped", label: "Partially Mapped" },
  { value: "all_mapped", label: "All mapped" },
];

const getMappingStatus = (variantTitle) => {
  const mappedCount = Number(variantTitle.mapped_count) || 0;
  const variantCount = Number(variantTitle.variant_count) || 0;

  if (variantCount > 0 && mappedCount >= variantCount) {
    return "all_mapped";
  }

  if (mappedCount > 0) {
    return "partially_mapped";
  }

  return "not_mapped";
};

function BulkMappingView({
  storeUid,
  variantTitles,
  createUrl,
  productTypeImages = {},
  borderMappings = [],
}) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedVariantTitle, setSelectedVariantTitle] = useState(null);
  const [isCreating, setIsCreating] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [overwriteMode, setOverwriteMode] = useState(false);
  const [mappingStatusFilter, setMappingStatusFilter] = useState("not_mapped");

  const mappingStatusCounts = variantTitles.reduce(
    (counts, vt) => {
      counts[getMappingStatus(vt)] += 1;
      return counts;
    },
    { not_mapped: 0, partially_mapped: 0, all_mapped: 0 }
  );

  const activeFilterLabel =
    mappingStatusFilters.find((filter) => filter.value === mappingStatusFilter)
      ?.label || "variant";

  const normalizedSearchQuery = searchQuery.trim().toLowerCase();

  const filteredVariantTitles = variantTitles.filter((vt) => {
    const matchesStatus = getMappingStatus(vt) === mappingStatusFilter;
    const matchesSearch =
      normalizedSearchQuery.length === 0 ||
      vt.title.toLowerCase().includes(normalizedSearchQuery);

    return matchesStatus && matchesSearch;
  });

  const handleBulkAssign = (variantTitle, overwrite = false) => {
    setSelectedVariantTitle(variantTitle);
    setOverwriteMode(overwrite);
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
          overwrite: overwriteMode,
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
      setOverwriteMode(false);
    }
  };

  const handleModalClose = () => {
    if (!isCreating) {
      setIsModalOpen(false);
      setSelectedVariantTitle(null);
      setOverwriteMode(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Search and Stats */}
      <div className="bg-white border border-slate-200 rounded-lg p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between mb-4">
          <div>
            <h2 className="text-lg font-semibold text-slate-900">
              Variant Titles
            </h2>
            <p className="text-sm text-slate-600">
              {variantTitles.length} unique variant title
              {variantTitles.length !== 1 ? "s" : ""} found across all products
            </p>
          </div>

          <div className="relative w-full sm:w-auto">
            <input
              type="text"
              placeholder="Search variant titles..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full sm:w-64 px-4 py-2 border border-slate-300 rounded-md text-sm focus:ring-2 focus:ring-slate-900 focus:border-slate-900"
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

        <fieldset className="mb-4">
          <legend className="sr-only">Mapping status</legend>
          <div className="flex w-full flex-col rounded-md shadow-sm sm:inline-flex sm:w-auto sm:flex-row">
            {mappingStatusFilters.map((filter, index) => {
              const isSelected = mappingStatusFilter === filter.value;
              const positionClass =
                index === 0
                  ? "rounded-t-md sm:rounded-l-md sm:rounded-tr-none"
                  : index === mappingStatusFilters.length - 1
                    ? "-mt-px rounded-b-md sm:-ml-px sm:mt-0 sm:rounded-bl-none sm:rounded-r-md"
                    : "-mt-px sm:-ml-px sm:mt-0";

              return (
                <label
                  key={filter.value}
                  className={`relative inline-flex w-full cursor-pointer items-center justify-between gap-2 border px-4 py-2 text-sm font-medium transition-colors focus-within:z-10 focus-within:ring-2 focus-within:ring-slate-900 focus-within:ring-offset-2 sm:w-auto sm:justify-center ${positionClass} ${
                    isSelected
                      ? "z-10 border-slate-900 bg-slate-900 text-white"
                      : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50"
                  }`}
                >
                  <input
                    type="radio"
                    name="mapping_status_filter"
                    value={filter.value}
                    checked={isSelected}
                    onChange={() => setMappingStatusFilter(filter.value)}
                    className="sr-only"
                  />
                  <span>{filter.label}</span>
                  <span
                    className={`min-w-6 rounded-full px-2 py-0.5 text-center text-xs font-semibold ${
                      isSelected
                        ? "bg-slate-700 text-white"
                        : "bg-slate-100 text-slate-600"
                    }`}
                  >
                    {mappingStatusCounts[filter.value]}
                  </span>
                </label>
              );
            })}
          </div>
        </fieldset>

        {/* Variant Titles Table */}
        {filteredVariantTitles.length === 0 ? (
          <div className="text-center py-8 text-slate-500">
            {normalizedSearchQuery
              ? `No ${activeFilterLabel.toLowerCase()} variant titles match your search`
              : `No ${activeFilterLabel.toLowerCase()} variant titles found in this store`}
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
                      {getMappingStatus(vt) === "all_mapped" ? (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                          <SvgIcon
                            name="CheckIcon"
                            className="w-3 h-3 mr-1"
                          />
                          All mapped
                        </span>
                      ) : getMappingStatus(vt) === "partially_mapped" ? (
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
                          {" · "}
                          <button
                            onClick={() => handleBulkAssign(vt.title, true)}
                            disabled={isCreating}
                            className="text-slate-400 hover:text-slate-600 underline disabled:opacity-50 disabled:cursor-not-allowed"
                          >
                            Overwrite
                          </button>
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
        borderMappings={borderMappings}
      />
    </div>
  );
}

export default BulkMappingView;
