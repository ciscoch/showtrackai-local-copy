module.exports = async function postResponseHook(context) {
  console.log("[Claude Post-Response]", context?.response?.completion?.slice(0,100));
  return context;
};
