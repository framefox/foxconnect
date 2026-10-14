import React, { useState } from "react";
import Modal from "react-modal";
import axios from "axios";

export default function MapRemainingAllModal({ isOpen, onClose, variantTitles, url, result, onResult, onBusyChange }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const remainingCount = variantTitles.reduce((sum, row) => sum + Number(row.unmapped_count || 0), 0);

  const confirm = async () => {
    if (busy || result) return;
    setBusy(true);
    onBusyChange(true);
    setError(null);
    try {
      const response = await axios.post(url, { variant_titles: variantTitles.map((row) => row.title) }, {
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
          "X-Requested-With": "XMLHttpRequest" },
      });
      onResult(response.data);
    } catch (err) {
      setError(err.response?.data?.error || "Could not confirm which jobs were queued. Refresh the list before trying again; any jobs already queued will continue.");
    } finally {
      setBusy(false);
      onBusyChange(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onRequestClose={busy ? undefined : onClose}
      shouldCloseOnOverlayClick={!busy} shouldCloseOnEsc={!busy}
      aria={{ labelledby: "map-all-title", describedby: "map-all-description" }}
      className="bg-white rounded-xl shadow-xl p-6 w-full max-w-xl max-h-[85vh] overflow-y-auto outline-none"
      overlayClassName="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
      <h2 id="map-all-title" className="text-lg font-semibold text-slate-900">
        {result ? "Mapping requests queued" : "Map remaining variants for all?"}
      </h2>
      <div id="map-all-description" className="mt-3 space-y-3 text-sm text-slate-600">
        {result ? (
          <>
            <p role="status">Queued {result.queued.length} of {variantTitles.length} variant titles. Mapping runs in the background; open a job below to check its progress.</p>
            {result.queued.length > 0 && <ul className="space-y-2">
              {result.queued.map((row) => <li key={row.title}><a href={row.redirect_url} target="_blank" rel="noopener noreferrer" className="text-slate-900 underline">{row.title} — View progress</a></li>)}
            </ul>}
            {result.skipped.length > 0 && <div>
              <h3 className="font-medium text-slate-900">Not queued ({result.skipped.length})</h3>
              <ul className="mt-2 space-y-2">{result.skipped.map((row) => <li key={row.title}><strong>{row.title}:</strong> {row.error}</li>)}</ul>
            </div>}
          </>
        ) : (
          <>
            <p>This will map the remaining {remainingCount} variants across all {variantTitles.length} partially mapped variant titles in this store, including titles hidden by your search.</p>
            <p>Each title will reuse its own existing Framefox product mapping. Already mapped variants will be left unchanged.</p>
            <p>Titles with different existing mappings or bundles will be skipped and listed for manual Bulk Assign.</p>
            <p>The jobs will run in the background. Keep this window open until the requests have been queued.</p>
          </>
        )}
      </div>
      {error && <p role="alert" className="mt-4 text-sm text-red-700">{error}</p>}
      <div className="mt-6 flex justify-end gap-3">
        <button type="button" disabled={busy} onClick={onClose} className="px-4 py-2 text-sm font-medium rounded-md border border-slate-300 disabled:opacity-50">{result || error ? "Close" : "Cancel"}</button>
        {result || error ? (
          <button type="button" onClick={() => window.location.reload()} className="px-4 py-2 text-sm font-medium rounded-md bg-slate-900 text-white">Refresh list</button>
        ) : (
          <button type="button" disabled={busy || variantTitles.length === 0} onClick={confirm} className="px-4 py-2 text-sm font-medium rounded-md bg-slate-900 text-white disabled:opacity-50">{busy ? "Queuing mappings…" : "Map remaining variants for all"}</button>
        )}
      </div>
    </Modal>
  );
}
