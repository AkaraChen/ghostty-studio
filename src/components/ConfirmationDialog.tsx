import { useEffect, useRef } from "react";
import { AlertTriangle } from "lucide-react";
import type { ConfirmationPrompt } from "../types";
import { useDialogFocus } from "./useDialogFocus";

interface ConfirmationDialogProps {
  prompt: ConfirmationPrompt;
  processing: boolean;
  onCancel(): void;
  onConfirm(): void;
}

export function ConfirmationDialog({
  prompt,
  processing,
  onCancel,
  onConfirm,
}: ConfirmationDialogProps) {
  const dialogRef = useDialogFocus(onCancel, processing);
  const submittedRef = useRef(false);

  useEffect(() => {
    if (!processing) submittedRef.current = false;
  }, [processing]);

  const confirmOnce = () => {
    if (processing || submittedRef.current) return;
    submittedRef.current = true;
    onConfirm();
  };

  return (
    <div
      className="review-backdrop"
      role="presentation"
      onMouseDown={() => {
        if (!processing) onCancel();
      }}
    >
      <section
        ref={dialogRef}
        className="review-panel confirmation-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="confirmation-title"
        aria-describedby="confirmation-message"
        aria-busy={processing}
        tabIndex={-1}
        onMouseDown={(event) => event.stopPropagation()}
      >
        <header className="review-header">
          <div>
            <span className="eyebrow"><AlertTriangle size={14} /> 需要确认</span>
            <h2 id="confirmation-title">{prompt.title}</h2>
          </div>
        </header>

        <div className="review-body">
          <p className="confirmation-message" id="confirmation-message">{prompt.message}</p>
        </div>

        <footer className="review-footer">
          <button
            type="button"
            className="button button--secondary"
            disabled={processing}
            onClick={onCancel}
            data-dialog-initial-focus
          >
            取消
          </button>
          <button
            type="button"
            className="button button--primary"
            disabled={processing}
            onClick={confirmOnce}
          >
            {processing ? "处理中…" : prompt.title}
          </button>
        </footer>
      </section>
    </div>
  );
}
