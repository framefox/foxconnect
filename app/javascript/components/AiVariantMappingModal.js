import React, { useState } from "react";
import axios from "axios";
import { SvgIcon } from "../components";

function AiVariantMappingModal({
  isOpen,
  onClose,
  product,
  store,
  variants,
  unmappedCount,
  onMappingsCreated,
}) {
  const [step, setStep] = useState("explanation"); // explanation, loading, review, creating, success, error
  const [suggestions, setSuggestions] = useState([]);
  const [skippedVariants, setSkippedVariants] = useState([]);
  const [selectedSuggestions, setSelectedSuggestions] = useState({});
  const [error, setError] = useState(null);
  const [matchedCount, setMatchedCount] = useState(0);
  const [skippedCount, setSkippedCount] = useState(0);

  if (!isOpen) return null;

  const toggleSuggestion = (index) => {
    setSelectedSuggestions((prev) => ({
      ...prev,
      [index]: !prev[index],
    }));
  };

  const toggleAll = () => {
    const allSelected =
      Object.keys(selectedSuggestions).length === suggestions.length &&
      Object.values(selectedSuggestions).every(Boolean);

    if (allSelected) {
      setSelectedSuggestions({});
    } else {
      const newSelected = {};
      suggestions.forEach((_, index) => {
        newSelected[index] = true;
      });
      setSelectedSuggestions(newSelected);
    }
  };

  const selectedCount =
    Object.values(selectedSuggestions).filter(Boolean).length;

  const handleConfirmStart = async () => {
    setStep("loading");
    setError(null);

    try {
      const response = await axios.post(
        `/connections/stores/${store.id}/products/${product.id}/ai_variant_mapping/suggest`,
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

      if (response.data.success) {
        const loadedSuggestions = response.data.suggestions || [];
        setSuggestions(loadedSuggestions);
        setSkippedVariants(response.data.skipped_variants || []);
        setMatchedCount(response.data.matched_count || 0);
        setSkippedCount(response.data.skipped_count || 0);

        // Initialize all suggestions as selected
        const initialSelected = {};
        loadedSuggestions.forEach((_, index) => {
          initialSelected[index] = true;
        });
        setSelectedSuggestions(initialSelected);

        setStep("review");
      } else {
        setError(response.data.error || "Failed to generate suggestions");
        setStep("error");
      }
    } catch (err) {
      console.error("AI suggestion error:", err);
      setError(
        err.response?.data?.error ||
          "An error occurred while generating suggestions"
      );
      setStep("error");
    }
  };

  const handleConfirmCreate = async () => {
    setStep("creating");
    setError(null);

    // Filter to only include selected suggestions
    const selectedSuggestionsToCreate = suggestions.filter(
      (_, index) => selectedSuggestions[index]
    );

    try {
      const response = await axios.post(
        `/connections/stores/${store.id}/products/${product.id}/ai_variant_mapping`,
        {
          suggestions: selectedSuggestionsToCreate,
        },
        {
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": document
              .querySelector('meta[name="csrf-token"]')
              .getAttribute("content"),
          },
        }
      );

      if (response.data.success) {
        setStep("success");
        // Refresh the page after a brief delay to show success message
        setTimeout(() => {
          window.location.reload();
        }, 1500);
      } else {
        setError(
          response.data.errors?.join(", ") ||
            response.data.error ||
            "Failed to create mappings"
        );
        setStep("error");
      }
    } catch (err) {
      console.error("AI create mappings error:", err);
      setError(
        err.response?.data?.error || "An error occurred while creating mappings"
      );
      setStep("error");
    }
  };

  const handleClose = () => {
    // Reset state
    setStep("explanation");
    setSuggestions([]);
    setSkippedVariants([]);
    setSelectedSuggestions({});
    setError(null);
    setMatchedCount(0);
    setSkippedCount(0);
    onClose();
  };

  const formatCentsToPrice = (cents) => {
    if (!cents && cents !== 0) return "N/A";
    return `$${(cents / 100).toFixed(2)}`;
  };

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto">
      <div className="flex items-center justify-center min-h-screen px-4 pt-4 pb-20 text-center sm:p-0">
        {/* Background overlay */}
        <div
          className="fixed inset-0 transition-opacity bg-gray-500 opacity-75"
          onClick={
            step === "loading" || step === "creating" ? null : handleClose
          }
        ></div>

        {/* Modal panel */}
        <div className="relative inline-block w-full max-w-4xl px-4 pt-5 pb-4 overflow-hidden text-left align-bottom transition-all transform bg-white rounded-lg shadow-xl sm:my-8 sm:align-middle sm:p-6">
          {/* Explanation Step */}
          {step === "explanation" && (
            <>
              <div className="sm:flex sm:items-start">
                <div className="flex items-center justify-center flex-shrink-0 w-12 h-12 mx-auto bg-purple-100 rounded-full sm:mx-0 sm:h-10 sm:w-10">
                  <SvgIcon
                    name="ImageMagicIcon"
                    className="w-6 h-6 inline text-purple-600"
                  />{" "}
                </div>
                <div className="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left flex-1">
                  <h3 className="text-lg font-medium leading-6 text-gray-900">
                    AI Auto-Matching
                  </h3>
                  <div className="mt-4 space-y-3">
                    <p className="text-sm text-gray-600">
                      The AI will analyze your remaining{" "}
                      <strong>{unmappedCount}</strong> variant
                      {unmappedCount !== 1 ? "s" : ""} and automatically match
                      them to appropriate Framefox products.
                    </p>
                    <div className="bg-purple-50 rounded-lg p-4">
                      <h4 className="text-sm font-medium text-purple-900 mb-2">
                        How it works:
                      </h4>
                      <ul className="text-sm text-purple-700 space-y-1 list-disc list-inside">
                        <li>
                          Analyzes your existing variant names (eg. "Black /
                          A3") to match to our print sizes and frame colors.
                        </li>
                        <li>
                          Keeps mat borders, glazing, and paper type consistent
                          across all matching products.
                        </li>
                        <li>
                          Artwork and crop settings are copied across from your
                          existing variants.
                        </li>
                      </ul>
                    </div>
                    <p className="text-xs text-gray-500">
                      You'll be able to review all suggestions before
                      confirming.
                    </p>
                  </div>
                </div>
              </div>
              <div className="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
                <button
                  type="button"
                  onClick={handleConfirmStart}
                  className="inline-flex justify-center w-full px-4 py-2 text-base font-medium text-white bg-purple-600 border border-transparent rounded-md shadow-sm hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  Start AI Matching
                </button>
                <button
                  type="button"
                  onClick={handleClose}
                  className="inline-flex justify-center w-full px-4 py-2 mt-3 text-base font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 sm:mt-0 sm:w-auto sm:text-sm"
                >
                  Cancel
                </button>
              </div>
            </>
          )}

          {/* Loading Step */}
          {step === "loading" && (
            <div className="text-center py-12">
              <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600 mb-4"></div>
              <h3 className="text-lg font-medium text-gray-900 mb-2">
                AI is analyzing your variants...
              </h3>
              <p className="text-sm text-gray-600">
                This may take a few moments. Please wait.
              </p>
            </div>
          )}

          {/* Review Step */}
          {step === "review" && (
            <>
              <div>
                <h3 className="text-lg font-medium leading-6 text-gray-900 mb-4">
                  Review AI Suggestions
                </h3>
                <div className="mb-4 flex items-center justify-between bg-purple-50 rounded-lg p-3">
                  <div className="text-sm">
                    <span className="font-medium text-purple-900">
                      {matchedCount} confident match
                      {matchedCount !== 1 ? "es" : ""} found
                    </span>
                    {skippedCount > 0 && (
                      <span className="text-purple-700 ml-2">
                        ({skippedCount} variant{skippedCount !== 1 ? "s" : ""}{" "}
                        skipped - no confident match)
                      </span>
                    )}
                  </div>
                </div>

                {suggestions.length === 0 ? (
                  <div className="text-center py-8">
                    <p className="text-gray-600">
                      No confident matches found. The AI could not determine
                      appropriate frame SKUs for the remaining variants.
                    </p>
                  </div>
                ) : (
                  <div className="max-h-96 overflow-y-auto border border-gray-200 rounded-lg">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50 sticky top-0">
                        <tr>
                          <th className="px-4 py-3 text-left">
                            <input
                              type="checkbox"
                              checked={
                                suggestions.length > 0 &&
                                selectedCount === suggestions.length
                              }
                              onChange={toggleAll}
                              className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded cursor-pointer"
                            />
                          </th>
                          <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Variant
                          </th>
                          <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Matched Frame SKU
                          </th>
                          <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Price
                          </th>
                        </tr>
                      </thead>
                      <tbody className="bg-white divide-y divide-gray-200">
                        {suggestions.map((suggestion, index) => (
                          <tr key={index} className="hover:bg-gray-50">
                            <td className="px-4 py-3">
                              <input
                                type="checkbox"
                                checked={selectedSuggestions[index] || false}
                                onChange={() => toggleSuggestion(index)}
                                className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded cursor-pointer"
                              />
                            </td>
                            <td className="px-4 py-3 text-sm text-gray-900">
                              {suggestion.variant_title}
                            </td>
                            <td className="px-4 py-3">
                              <div className="text-sm text-gray-900">
                                {suggestion.frame_sku.title}
                              </div>
                              {suggestion.ai_reasoning && (
                                <div className="text-xs text-gray-500 mt-1">
                                  {suggestion.ai_reasoning}
                                </div>
                              )}
                            </td>
                            <td className="px-4 py-3 text-sm font-medium text-gray-900">
                              {formatCentsToPrice(
                                suggestion.frame_sku.cost_cents
                              )}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}

                {/* Skipped Variants Section */}
                {skippedVariants.length > 0 && (
                  <div className="mt-6">
                    <h4 className="text-sm font-medium text-gray-700 mb-3">
                      Skipped Variants (Debug Info)
                    </h4>
                    <div className="max-h-64 overflow-y-auto border border-yellow-200 rounded-lg bg-yellow-50">
                      <table className="min-w-full divide-y divide-yellow-200">
                        <thead className="bg-yellow-100 sticky top-0">
                          <tr>
                            <th className="px-4 py-2 text-left text-xs font-medium text-yellow-800 uppercase tracking-wider">
                              Variant
                            </th>
                            <th className="px-4 py-2 text-left text-xs font-medium text-yellow-800 uppercase tracking-wider">
                              Reason
                            </th>
                            <th className="px-4 py-2 text-left text-xs font-medium text-yellow-800 uppercase tracking-wider">
                              AI Response
                            </th>
                          </tr>
                        </thead>
                        <tbody className="bg-yellow-50 divide-y divide-yellow-200">
                          {skippedVariants.map((skipped, index) => (
                            <tr key={index}>
                              <td className="px-4 py-2 text-sm text-gray-900">
                                {skipped.variant_title}
                              </td>
                              <td className="px-4 py-2 text-xs text-gray-700">
                                {skipped.reason}
                              </td>
                              <td className="px-4 py-2 text-xs font-mono text-gray-600">
                                {skipped.ai_response ? (
                                  <details className="cursor-pointer">
                                    <summary className="text-purple-600 hover:text-purple-800">
                                      View LLM Response
                                    </summary>
                                    <pre className="mt-2 p-2 bg-white rounded border border-gray-300 overflow-x-auto text-xs">
                                      {JSON.stringify(
                                        skipped.ai_response,
                                        null,
                                        2
                                      )}
                                    </pre>
                                  </details>
                                ) : (
                                  <span className="text-gray-400">
                                    No AI response
                                  </span>
                                )}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}
              </div>
              <div className="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
                {suggestions.length > 0 && (
                  <button
                    type="button"
                    onClick={handleConfirmCreate}
                    disabled={selectedCount === 0}
                    className={`inline-flex justify-center w-full px-4 py-2 text-base font-medium text-white border border-transparent rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 sm:ml-3 sm:w-auto sm:text-sm ${
                      selectedCount === 0
                        ? "bg-gray-400 cursor-not-allowed"
                        : "bg-purple-600 hover:bg-purple-700"
                    }`}
                  >
                    Create {selectedCount} Mapping
                    {selectedCount !== 1 ? "s" : ""}
                  </button>
                )}
                <button
                  type="button"
                  onClick={handleClose}
                  className="inline-flex justify-center w-full px-4 py-2 mt-3 text-base font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 sm:mt-0 sm:w-auto sm:text-sm"
                >
                  Cancel
                </button>
              </div>
            </>
          )}

          {/* Creating Step */}
          {step === "creating" && (
            <div className="text-center py-12">
              <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600 mb-4"></div>
              <h3 className="text-lg font-medium text-gray-900 mb-2">
                Creating variant mappings...
              </h3>
              <p className="text-sm text-gray-600">Please wait.</p>
            </div>
          )}

          {/* Success Step */}
          {step === "success" && (
            <div className="text-center py-12">
              <div className="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-green-100 mb-4">
                <svg
                  className="h-6 w-6 text-green-600"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M5 13l4 4L19 7"
                  />
                </svg>
              </div>
              <h3 className="text-lg font-medium text-gray-900 mb-2">
                Variant mappings created successfully!
              </h3>
              <p className="text-sm text-gray-600">
                Refreshing to show your new mappings...
              </p>
            </div>
          )}

          {/* Error Step */}
          {step === "error" && (
            <>
              <div className="sm:flex sm:items-start">
                <div className="flex items-center justify-center flex-shrink-0 w-12 h-12 mx-auto bg-red-100 rounded-full sm:mx-0 sm:h-10 sm:w-10">
                  <svg
                    className="w-6 h-6 text-red-600"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                    />
                  </svg>
                </div>
                <div className="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left flex-1">
                  <h3 className="text-lg font-medium leading-6 text-gray-900">
                    Error
                  </h3>
                  <div className="mt-2">
                    <p className="text-sm text-red-600">{error}</p>
                  </div>
                </div>
              </div>
              <div className="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
                <button
                  type="button"
                  onClick={handleClose}
                  className="inline-flex justify-center w-full px-4 py-2 text-base font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 sm:w-auto sm:text-sm"
                >
                  Close
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

export default AiVariantMappingModal;
