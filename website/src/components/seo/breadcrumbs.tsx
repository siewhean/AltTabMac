import Link from "next/link";

export type BreadcrumbItem = {
  name: string;
  path: "/" | `/${string}`;
};

export function Breadcrumbs({
  items,
}: {
  items: ReadonlyArray<BreadcrumbItem>;
}) {
  return (
    <nav aria-label="Breadcrumb" className="mb-7 text-sm text-subdued">
      <ol className="flex flex-wrap items-center gap-2">
        {items.map((item, index) => {
          const isCurrent = index === items.length - 1;
          return (
            <li key={item.path} className="flex items-center gap-2">
              {index > 0 ? <span aria-hidden="true">/</span> : null}
              {isCurrent ? (
                <span aria-current="page" className="text-muted">
                  {item.name}
                </span>
              ) : (
                <Link
                  href={item.path}
                  className="transition-colors duration-200 hover:text-text"
                >
                  {item.name}
                </Link>
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
