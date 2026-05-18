import React, { useState, useEffect, useMemo } from "react";
import axios from "axios";

function CopyMappingsModal({
  isOpen,
  onClose,
  product,
  candidatesUrl,
  copyUrl,
  csrfToken,
}) {
  const [step, setStep] = useState("picker");
  const [candidates, setCandidates] = useState([]);
  const [targetVariantCount, setTargetVariantCount] = useState(
    product?.variant_count || 0
  );
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState("");
  const [selected, setSelected] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (!isOpen) return;

    setStep("picker");
    setSelected(null);
    setFilter("");
    setError(null);
    setLoading(true);

    axios
      .get(candidatesUrl, {
        headers: { Accept: "application/json" },
      })
      .then((response) => {
        setCandidates(response.data?.candidates || []);
        setTargetVariantCount(
          response.data?.target_variant_count ?? product?.variant_count ?? 0
        );
        setLoading(false);
      })
      .catch((err) => {
        console.error("Failed to load copy-mapping candidates", err);
        setError(
          err.response?.data?.error ||
            "Could not load products. Please try again."
        );
        setLoading(false);
      });
  }, [isOpen, candidatesUrl, product]);

  const filteredCandidates = useMemo(() => {
    const term = filter.trim().toLowerCase();
    if (!term) return candidates;
    return candidates.filter((c) => c.title.toLowerCase().includes(term));
  }, [filter, candidates]);

  if (!isOpen) return null;

  const handleSelect = (candidate) => {
    if (candidate.matching_variant_count === 0) return;
    setSelected(candidate);
    setStep("confirm");
  };

  const handleConfirm = () => {
    if (!selected || isSubmitting) return;
    setIsSubmitting(true);

    axios
      .post(
        copyUrl,
        { source_product_id: selected.id },
        {
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": csrfToken,
            Accept: "application/json, text/html",
          },
          maxRedirects: 0,
          validateStatus: (status) =>
            (status >= 200 && status < 300) || status === 302,
        }
      )
      .then(() => {
        window.location.reload();
      })
      .catch((err) => {
        console.error("Failed to copy mappings", err);
        setIsSubmitting(false);
        if (err.response && err.response.status < 400) {
          window.location.reload();
        } else {
          setError(
            err.response?.data?.error ||
              "Could not copy mappings. Please try again."
          );
        }
      });
  };

  const handleBack = () => {
    setStep("picker");
    setSelected(null);
  };

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto">
      <div
        className="fixed inset-0 bg-black opacity-50 transition-opacity"
        onClick={!isSubmitting ? onClose : undefined}
      ></div>

      <div className="flex min-h-full items-center justify-center p-4">
        <div
          className="relative bg-white rounded-xl shadow-2xl max-w-2xl w-full"
          onClick={(e) => e.stopPropagation()}
        >
          <button
            type="button"
            onClick={onClose}
            disabled={isSubmitting}
            className="absolute top-4 right-4 text-slate-400 hover:text-slate-600 transition-colors disabled:opacity-50"
            aria-label="Close"
          >
            <svg
              className="w-5 h-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>

          {step === "picker" && (
            <PickerStep
              product={product}
              loading={loading}
              error={error}
              candidates={filteredCandidates}
              filter={filter}
              onFilterChange={setFilter}
              onSelect={handleSelect}
              onCancel={onClose}
              targetVariantCount={targetVariantCount}
            />
          )}

          {step === "confirm" && selected && (
            <ConfirmStep
              product={product}
              source={selected}
              targetVariantCount={targetVariantCount}
              isSubmitting={isSubmitting}
              error={error}
              onConfirm={handleConfirm}
              onBack={handleBack}
            />
          )}
        </div>
      </div>
    </div>
  );
}

function PickerStep({
  product,
  loading,
  error,
  candidates,
  filter,
  onFilterChange,
  onSelect,
  onCancel,
  targetVariantCount,
}) {
  return (
    <div className="p-6">
      <h3 className="text-lg font-semibold text-slate-900 mb-1 pr-8">
        Copy mappings from another product
      </h3>
      <p className="text-sm text-slate-600 mb-4">
        Pick a product to copy variant mappings onto{" "}
        <span className="font-medium text-slate-900">{product?.title}</span>.
        Only products with existing mappings are shown.
      </p>

      <input
        type="text"
        value={filter}
        onChange={(e) => onFilterChange(e.target.value)}
        placeholder="Search products…"
        className="w-full mb-4 px-3 py-2 border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-slate-500"
      />

      {loading && (
        <div className="text-sm text-slate-500 py-8 text-center">
          <i className="fa-solid fa-spinner-third fa-spin mr-2"></i>
          Loading products…
        </div>
      )}

      {error && !loading && (
        <div className="text-sm text-red-600 py-4">{error}</div>
      )}

      {!loading && !error && candidates.length === 0 && (
        <div className="text-sm text-slate-500 py-8 text-center">
          No other products in this store have variant mappings yet.
        </div>
      )}

      {!loading && !error && candidates.length > 0 && (
        <ul className="max-h-96 overflow-y-auto divide-y divide-slate-200 border border-slate-200 rounded-md">
          {candidates.map((candidate) => {
            const noMatches = candidate.matching_variant_count === 0;
            return (
              <li key={candidate.id}>
                <button
                  type="button"
                  onClick={() => onSelect(candidate)}
                  disabled={noMatches}
                  className={`w-full flex items-center justify-between gap-3 px-4 py-3 text-left transition-colors ${
                    noMatches
                      ? "opacity-50 cursor-not-allowed"
                      : "hover:bg-slate-50"
                  }`}
                >
                  <div className="flex items-center gap-3 min-w-0">
                    {candidate.featured_image_url ? (
                      <img
                        src={candidate.featured_image_url}
                        alt=""
                        className="w-10 h-10 rounded object-cover bg-slate-100 flex-shrink-0"
                      />
                    ) : (
                      <div className="w-10 h-10 rounded bg-slate-100 flex-shrink-0" />
                    )}
                    <div className="min-w-0">
                      <div className="text-sm font-medium text-slate-900 truncate">
                        {candidate.title}
                      </div>
                      <div className="text-xs text-slate-500">
                        {candidate.variant_count} variant
                        {candidate.variant_count === 1 ? "" : "s"}
                        {candidate.bundles_enabled ? " · bundles enabled" : ""}
                      </div>
                    </div>
                  </div>

                  <MatchBadge
                    matching={candidate.matching_variant_count}
                    total={targetVariantCount}
                  />
                </button>
              </li>
            );
          })}
        </ul>
      )}

      <div className="flex justify-end mt-6">
        <button
          type="button"
          onClick={onCancel}
          className="px-4 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-md hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 transition-colors"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}

function MatchBadge({ matching, total }) {
  let tone = "bg-slate-100 text-slate-600";
  if (matching > 0 && matching === total) tone = "bg-emerald-100 text-emerald-800";
  else if (matching > 0) tone = "bg-amber-100 text-amber-800";

  return (
    <span
      className={`inline-flex items-center whitespace-nowrap text-xs font-medium px-2.5 py-1 rounded-full ${tone}`}
    >
      {matching} of {total} variant{total === 1 ? "" : "s"} match
    </span>
  );
}

function ConfirmStep({
  product,
  source,
  targetVariantCount,
  isSubmitting,
  error,
  onConfirm,
  onBack,
}) {
  return (
    <div className="p-6">
      <h3 className="text-lg font-semibold text-slate-900 mb-4 pr-8">
        Confirm copy mappings
      </h3>

      <div className="space-y-3 text-sm text-slate-700 mb-4">
        <p>
          We'll copy all of the product mappings from{" "}
          <span className="font-medium text-slate-900">{source.title}</span>{" "}
          over to{" "}
          <span className="font-medium text-slate-900">{product.title}</span>.
          Images will not be copied, only the product mappings.
        </p>
        <p className="text-slate-600">
          {source.matching_variant_count} of {targetVariantCount} variant
          {targetVariantCount === 1 ? "" : "s"} on {product.title} will be
          updated (matched by variant name).
        </p>
      </div>

      <div className="bg-amber-50 border border-amber-200 rounded-md p-4 mb-6">
        <div className="flex items-start gap-2 text-sm text-amber-900">
          <i className="fa-solid fa-triangle-exclamation mt-0.5"></i>
          <div>
            <p className="font-medium">Heads up</p>
            <p className="mt-1">
              This action will remove all product and image mappings you
              currently have on{" "}
              <span className="font-medium">{product.title}</span> for variants
              that match by name. This cannot be undone.
            </p>
          </div>
        </div>
      </div>

      {error && <div className="text-sm text-red-600 mb-4">{error}</div>}

      <div className="flex justify-between">
        <button
          type="button"
          onClick={onBack}
          disabled={isSubmitting}
          className="px-4 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-md hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          Back
        </button>
        <button
          type="button"
          onClick={onConfirm}
          disabled={isSubmitting}
          className="px-4 py-2 text-sm font-medium text-white bg-slate-900 rounded-md hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors inline-flex items-center"
        >
          {isSubmitting ? (
            <>
              <i className="fa-solid fa-spinner-third fa-spin mr-2"></i>
              Copying…
            </>
          ) : (
            "Confirm and copy"
          )}
        </button>
      </div>
    </div>
  );
}

export default CopyMappingsModal;
