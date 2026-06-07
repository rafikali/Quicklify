interface Step {
  text: string;
}

interface HowToNoteProps {
  title?: string;
  /** Plain bullet list of admin actions in this section. */
  whatToDo: Array<string | Step>;
  /** Plain bullet list of how a tester verifies it on the mobile app. */
  howToVerify: Array<string | Step>;
  /** Optional final tip (rebuild, propagation delay, etc.). */
  tip?: string;
  /** Open by default. Defaults to false so it doesn't crowd the page. */
  defaultOpen?: boolean;
}

/**
 * A collapsible help card. Drop one at the top of each admin section so new
 * admins know what the section does, what action to take, and how to
 * verify the change reached the mobile app.
 */
export function HowToNote({
  title = 'How to use this section',
  whatToDo,
  howToVerify,
  tip,
  defaultOpen = false,
}: HowToNoteProps) {
  return (
    <details
      open={defaultOpen}
      className="group bg-primary/5 border border-primary/30 rounded-xl mb-6 overflow-hidden"
    >
      <summary className="px-4 py-3 cursor-pointer text-sm font-medium text-primary flex items-center justify-between select-none">
        <span>{title}</span>
        <span className="text-xs text-muted group-open:hidden">show ▾</span>
        <span className="text-xs text-muted hidden group-open:inline">hide ▴</span>
      </summary>
      <div className="px-4 pb-4 pt-1 text-sm space-y-4 border-t border-primary/20">
        <div>
          <h4 className="text-xs uppercase tracking-wider text-muted mb-2">
            What you do here
          </h4>
          <ol className="list-decimal list-inside space-y-1 text-text/90">
            {whatToDo.map((s, i) => (
              <li key={i}>{typeof s === 'string' ? s : s.text}</li>
            ))}
          </ol>
        </div>
        <div>
          <h4 className="text-xs uppercase tracking-wider text-muted mb-2">
            How to verify it on the mobile app
          </h4>
          <ol className="list-decimal list-inside space-y-1 text-text/90">
            {howToVerify.map((s, i) => (
              <li key={i}>{typeof s === 'string' ? s : s.text}</li>
            ))}
          </ol>
        </div>
        {tip && (
          <p className="text-xs text-muted bg-bg/60 border border-border rounded px-3 py-2">
            <span className="font-medium text-text">Tip:</span> {tip}
          </p>
        )}
      </div>
    </details>
  );
}
