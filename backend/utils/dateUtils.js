/**
 * Consistently returns the current date in YYYY-MM-DD format
 * using the local server time (or a fixed offset if required).
 * This prevents the 'Midnight Bug' where UTC dates differ from local dates.
 */
function getLocalToday() {
    const now = new Date();
    // Offset for IST (UTC+5:30) if we want to be explicit, 
    // or just use local date methods which work on the server's local time.
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

/**
 * Converts any Date object to a YYYY-MM-DD string in local time
 */
function formatDateLocal(date) {
    if (!date) return getLocalToday();
    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

/**
 * Parses a YYYY-MM-DD string as local midnight instead of UTC.
 */
function parseLocalDate(dateStr) {
    if (!dateStr) return new Date();
    const [year, month, day] = dateStr.split('-').map(Number);
    return new Date(year, month - 1, day, 0, 0, 0, 0);
}

module.exports = {
    getLocalToday,
    formatDateLocal,
    parseLocalDate
};
