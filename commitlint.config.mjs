// Conventional Commits, one short sentence per commit: no body and no footers.
// Merge and revert commits are ignored by commitlint's defaults.
export default {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "header-max-length": [2, "always", 100],
    "subject-full-stop": [2, "never", "."],
    "body-empty": [2, "always"],
    "footer-empty": [2, "always"],
  },
};
