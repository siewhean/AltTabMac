export default function GlobalLoading() {
  return (
    <div className="flex min-h-[50vh] items-center justify-center p-8">
      <div className="flex flex-col items-center gap-3">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-cyan border-t-transparent" />
        <p className="text-sm font-medium text-subdued">Loading CmdTab...</p>
      </div>
    </div>
  );
}
