export default {
  transform: {},
  testEnvironment: "node",
  moduleFileExtensions: ["js"],
  globals: {
    "ts-jest": {
      useESM: true, // ESM (import/export) を有効化
    },
  },
};
