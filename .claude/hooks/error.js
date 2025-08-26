module.exports = async function errorHook(context) {
  console.error("[Claude Error Hook]", context?.error?.message || context?.error);
  return context;
};
