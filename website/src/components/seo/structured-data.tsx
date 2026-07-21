type JsonLdData = Record<string, unknown> | Array<Record<string, unknown>>;

export function StructuredData({ id, data }: { id: string; data: JsonLdData }) {
  return (
    <script
      id={id}
      type="application/ld+json"
      dangerouslySetInnerHTML={{
        __html: JSON.stringify(data).replace(/</g, "\\u003c"),
      }}
    />
  );
}

