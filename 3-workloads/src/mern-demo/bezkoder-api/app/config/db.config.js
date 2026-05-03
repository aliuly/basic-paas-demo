const { DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME, DB_SSL } = process.env;

const tlsParams = DB_SSL === 'true' ? '&ssl=true&tlsAllowInvalidCertificates=true' : '';

module.exports = {
  url: `mongodb://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?authSource=admin${tlsParams}`
};
