const crypto = require('crypto');

const hashSetupToken = (token) => {
    return crypto.createHash('sha256').update(token).digest('hex');
};

const createPasswordSetup = (user) => {
    const token = crypto.randomBytes(32).toString('hex');
    user.passwordSetupToken = hashSetupToken(token);
    user.passwordSetupExpires = new Date(Date.now() + 24 * 60 * 60 * 1000);
    return token;
};

const buildPasswordSetupLink = (token) => {
    const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:54623';
    return `${frontendUrl}/#/set-password?token=${token}`;
};

module.exports = {
    buildPasswordSetupLink,
    createPasswordSetup,
    hashSetupToken,
};
