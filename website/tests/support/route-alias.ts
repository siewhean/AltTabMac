import { registerHooks } from "node:module";
import path from "node:path";

// Route handlers import "@/..." (the Next.js tsconfig path alias). tsc keeps
// that specifier in its CommonJS output, so map it onto the compiled src/
// tree. Importing this module first lets tests require route files directly.
const compiledSourceRoot = path.resolve(__dirname, "../../src");

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier.startsWith("@/")) {
      return nextResolve(
        path.join(compiledSourceRoot, `${specifier.slice(2)}.js`),
        context,
      );
    }
    return nextResolve(specifier, context);
  },
});
