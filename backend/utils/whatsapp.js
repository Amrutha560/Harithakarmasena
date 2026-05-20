const twilio = require('twilio');

const normalizeIndianWhatsAppNumber = (phoneNumber) => {
    if (!phoneNumber) return null;
    const raw = phoneNumber.toString().trim();
    if (!raw) return null;

    if (raw.startsWith('+')) {
        return `whatsapp:${raw}`;
    }

    const digits = raw.replace(/\D/g, '');
    if (!digits) return null;

    if (digits.startsWith('91') && digits.length === 12) {
        return `whatsapp:+${digits}`;
    }

    if (digits.length === 10) {
        return `whatsapp:+91${digits}`;
    }

    return `whatsapp:+${digits}`;
};

const sendResidentApprovalWhatsApp = async ({
    to,
    username,
    temporaryPassword,
    loginPageLink,
    forcePasswordChange = true
}) => {
    const accountSid = process.env.TWILIO_ACCOUNT_SID;
    const authToken = process.env.TWILIO_AUTH_TOKEN;
    const from = process.env.TWILIO_WHATSAPP_FROM || 'whatsapp:+14155238886';
    const contentSid = process.env.TWILIO_RESIDENT_APPROVAL_CONTENT_SID;
    const destination = process.env.TWILIO_RESIDENT_TEST_TO || to;
    const normalizedTo = normalizeIndianWhatsAppNumber(destination);

    const instruction = forcePasswordChange
        ? 'Please login and change your password.'
        : 'Please login with this password. You can change it later from the Password menu.';

    const body = `Your HarithaKarmaSena account is approved.
Username: ${username}
Temporary Password: ${temporaryPassword}
Login here: ${loginPageLink}
${instruction}`;

    if (!normalizedTo) {
        return { sent: false, reason: 'Resident mobile number is missing or invalid', body };
    }

    const missingConfig = !accountSid
        ? 'Twilio Account SID is missing'
        : (!authToken || authToken === 'your_auth_token_here')
            ? 'Twilio Auth Token is missing'
            : !from
                ? 'Twilio WhatsApp sender is missing'
                : null;

    if (missingConfig) {
        console.log(`
--- TWILIO WHATSAPP NOT SENT: CONFIG MISSING ---
From: ${from}
To: ${normalizedTo}
${body}
-----------------------------------------------
`);
        return { sent: false, reason: missingConfig, to: normalizedTo, body };
    }

    const client = twilio(accountSid, authToken);
    const messagePayload = contentSid
        ? {
            from,
            to: normalizedTo,
            contentSid,
            contentVariables: JSON.stringify({
                1: username,
                2: temporaryPassword,
                3: loginPageLink
            })
        }
        : {
            from,
            to: normalizedTo,
            body
        };

    const message = await client.messages.create(messagePayload);

    return { sent: true, sid: message.sid, to: normalizedTo, usedTemplate: !!contentSid };
};

module.exports = {
    normalizeIndianWhatsAppNumber,
    sendResidentApprovalWhatsApp
};
