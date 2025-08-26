module.exports = async function preRequestHook(context) {
  console.log("[Claude Pre-Request]", context?.request?.prompt?.slice(0,100));
  return context;
};
