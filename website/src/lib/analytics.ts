export function analyticsAttributes(event: string, context?: string) {
  return {
    "data-analytics-event": event,
    ...(context ? { "data-analytics-context": context } : {}),
  };
}

