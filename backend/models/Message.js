const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
    threadId: { type: String, required: true }, // Usually the ID of the Concern or a unique thread ID
    sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    senderName: { type: String },
    senderRole: { type: String },
    recipient: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // Optional for broadcasts
    body: { type: String, required: true },
    attachmentPath: { type: String },
    timestamp: { type: Date, default: Date.now },
    isRead: { type: Boolean, default: false }
});

module.exports = mongoose.model('Message', messageSchema);
