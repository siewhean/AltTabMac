export default function DashboardLoading() {
  return (
    <div className="flex min-h-[50vh] items-center justify-center p-8">
      <div className="flex flex-col items-center gap-3">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-cyan border-t-transparent" />
        <p className="text-sm font-medium text-subdued">Loading admin dashboard...</p>
      </div>
    </div>
  );
}
