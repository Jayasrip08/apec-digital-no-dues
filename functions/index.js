/**
 * APEC Digital No-Dues - Cloud Functions
 * 
 * This file contains all Cloud Functions for:
 * 1. Automated payment deadline reminders
 * 2. Payment status change notifications
 * 3. Student activity tracking
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const emailService = require("./email_service.js");

// Initialize Firebase Admin
admin.initializeApp();

// Set global options for all functions
setGlobalOptions({
  maxInstances: 10,
  region: "asia-south1", // Mumbai region for India
});

/**
 * Scheduled function to send payment deadline reminders
 * Runs daily at 10:00 AM IST
 */
exports.sendEmailMethods = emailService.sendEmailReminders;
exports.sendPaymentReminders = onSchedule({
  schedule: "0 10 * * *", // Every day at 10:00 AM
  timeZone: "Asia/Kolkata",
  region: "asia-south1",
}, async (event) => {
  logger.info("Starting payment reminder job");

  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const nowDate = now.toDate();

  try {
    // Get all active semesters
    const semestersSnapshot = await db.collection("semesters")
      .where("isActive", "==", true)
      .get();

    logger.info(`Found ${semestersSnapshot.size} active semesters`);

    for (const semDoc of semestersSnapshot.docs) {
      const semester = semDoc.data();

      // Get fee structures for this semester
      const feeStructuresSnapshot = await db.collection("fee_structures")
        .where("semester", "==", semDoc.id)
        .get();

      logger.info(`Processing ${feeStructuresSnapshot.size} fee structures for ${semDoc.id}`);

      for (const feeDoc of feeStructuresSnapshot.docs) {
        const feeData = feeDoc.data();

        // Check if deadline exists
        if (!feeData.deadline) continue;

        const deadline = feeData.deadline.toDate();
        const daysUntilDeadline = Math.ceil(
          (deadline.getTime() - nowDate.getTime()) / (1000 * 60 * 60 * 24),
        );

        logger.info(`Deadline in ${daysUntilDeadline} days for ${feeDoc.id}`);

        // Send reminder if deadline is in 7, 3, or 1 day(s)
        if ([7, 3, 1].includes(daysUntilDeadline)) {
          await sendRemindersForFeeStructure(
            feeDoc.id,
            feeData,
            daysUntilDeadline,
          );
        }
      }
    }

    logger.info("Payment reminder job completed successfully");
    return null;
  } catch (error) {
    logger.error("Error in payment reminder job:", error);
    throw error;
  }
});

/**
 * Helper function to send reminders for a specific fee structure
 */
async function sendRemindersForFeeStructure(
  feeStructureId,
  feeData,
  daysUntilDeadline,
) {
  const db = admin.firestore();

  try {
    // Find students matching this fee structure who haven't paid
    const usersSnapshot = await db.collection("users")
      .where("role", "==", "student")
      .where("dept", "==", feeData.dept)
      .where("quotaCategory", "==", feeData.quotaCategory)
      .where("status", "==", "Pending") // Only unpaid students
      .get();

    logger.info(`Found ${usersSnapshot.size} students to remind for ${feeStructureId}`);

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        logger.warn(`No FCM token for user ${userDoc.id}`);
        continue;
      }

      // Calculate outstanding amount
      const outstandingAmount = feeData.amount - (userData.paidFee || 0);

      if (outstandingAmount <= 0) {
        // Student has already paid
        continue;
      }

      // Prepare notification message
      const title = "⚠️ Fee Payment Reminder";
      const body = `Your fee payment deadline is in ${daysUntilDeadline} day(s). Amount due: ₹${outstandingAmount}`;

      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: "payment_reminder",
          amount: String(outstandingAmount),
          deadline: feeData.deadline.toDate().toISOString(),
          daysRemaining: String(daysUntilDeadline),
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            color: "#FF6B35",
          },
        },
      };

      try {
        // Send FCM notification
        const response = await admin.messaging().send(message);
        logger.info(`Notification sent to ${userData.email}: ${response}`);

        // Log notification in Firestore
        await db.collection("notifications").add({
          userId: userDoc.id,
          type: "payment_reminder",
          title: title,
          body: body,
          data: message.data,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
          fcmMessageId: response,
        });
      } catch (error) {
        logger.error(`Failed to send notification to ${userData.email}:`, error);
      }
    }
  } catch (error) {
    logger.error(`Error sending reminders for ${feeStructureId}:`, error);
  }
}

/**
 * Trigger when payment status changes
 * Sends notification to student when admin verifies or rejects payment
 */
exports.onPaymentStatusChangeV2 = onDocumentUpdated({
  document: "payments/{paymentId}",
  region: "asia-south1",
}, async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  // Check if status changed
  if (before.status === after.status) {
    return null;
  }

  logger.info(`Payment status changed from ${before.status} to ${after.status} for payment ${event.params.paymentId}`);

  const db = admin.firestore();

  try {
    // Get student data
    const studentDoc = await db.collection("users").doc(after.studentId).get();

    if (!studentDoc.exists) {
      logger.error(`Student not found: ${after.studentId}`);
      return null;
    }

    const studentData = studentDoc.data();
    const fcmToken = studentData.fcmToken;

    if (!fcmToken) {
      logger.warn(`No FCM token for student ${after.studentId}`);
      return null;
    }

    let title = "";
    let body = "";
    let notificationType = "";

    // Prepare notification based on new status
    if (after.status === "verified") {
      title = "✅ Payment Verified";
      body = `Your payment of ₹${after.amount} has been verified successfully!`;
      notificationType = "payment_verified";
    } else if (after.status === "rejected") {
      title = "❌ Payment Rejected";
      body = `Your payment was rejected. ${after.rejectionReason ? "Reason: " + after.rejectionReason : "Please contact admin."}`;
      notificationType = "payment_rejected";
    } else if (after.status === "under_review") {
      title = "🔍 Payment Under Review";
      body = `Your payment of ₹${after.amount} is being reviewed by the admin.`;
      notificationType = "payment_under_review";
    } else {
      // Unknown status, don't send notification
      return null;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: notificationType,
        status: after.status,
        paymentId: event.params.paymentId,
        amount: String(after.amount),
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          color: after.status === "verified" ? "#4CAF50" : "#F44336",
        },
      },
    };

    // Send FCM notification
    const response = await admin.messaging().send(message);
    logger.info(`Status change notification sent to ${studentData.email}: ${response}`);

    // Log notification in Firestore
    await db.collection("notifications").add({
      userId: after.studentId,
      type: notificationType,
      title: title,
      body: body,
      data: message.data,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      fcmMessageId: response,
    });

    // Send Email notification
    await emailService.sendPaymentStatusEmail(after, studentData.email, studentData.name);

    return null;
  } catch (error) {
    logger.error("Error sending payment status notification:", error);
    throw error;
  }
});

/**
 * Helper function to calculate peak activity time for a user
 * Analyzes user's activity patterns to send notifications at optimal times
 */
async function calculatePeakActivityTime(userId) {
  const db = admin.firestore();

  try {
    const userDoc = await db.collection("users").doc(userId).get();

    if (!userDoc.exists) {
      return 10; // Default to 10 AM
    }

    const lastActiveAt = userDoc.data().lastActiveAt;

    if (lastActiveAt) {
      const hour = lastActiveAt.toDate().getHours();
      return hour;
    }

    return 10; // Default to 10 AM
  } catch (error) {
    logger.error(`Error calculating peak time for ${userId}:`, error);
    return 10;
  }
}

/**
 * Trigger when a new user is created
 * Sends welcome notification
 */
exports.onUserCreated = onDocumentUpdated({
  document: "users/{userId}",
  region: "asia-south1",
}, async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  // Check if fcmToken was just added (user logged in for first time)
  if (!before.fcmToken && after.fcmToken && after.role === "student") {
    const db = admin.firestore();

    const message = {
      token: after.fcmToken,
      notification: {
        title: "Welcome to APEC Digital No-Dues",
        body: `Hello ${after.name}! You can now manage your fee payments digitally.`,
      },
      data: {
        type: "welcome",
      },
    };

    try {
      await admin.messaging().send(message);
      logger.info(`Welcome notification sent to ${after.email}`);

      // Log notification
      await db.collection("notifications").add({
        userId: event.params.userId,
        type: "welcome",
        title: message.notification.title,
        body: message.notification.body,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      });
    } catch (error) {
      logger.error(`Failed to send welcome notification:`, error);
    }
  }

  return null;
});
