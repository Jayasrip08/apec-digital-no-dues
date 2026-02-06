/**
 * Email Reminder Service - Cloud Function
 * 
 * This function sends email reminders for payment deadlines
 * as an alternative/supplement to FCM notifications
 * 
 * Note: Requires SendGrid or similar email service API key
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

const sgMail = require('@sendgrid/mail');
// Use environment variable for API key - set this in Firebase Functions config
const sendgridApiKey = process.env.SENDGRID_API_KEY || "";
sgMail.setApiKey(sendgridApiKey);

setGlobalOptions({
  maxInstances: 10,
  region: "asia-south1",
});

/**
 * Send email using SendGrid
 */
async function sendEmail(to, subject, htmlContent) {
  logger.info(`Sending email to ${to}: ${subject}`);

  const msg = {
    to: to,
    from: 'jayasrip1808@gmail.com', // Your verified sender
    subject: subject,
    html: htmlContent,
  };

  try {
    await sgMail.send(msg);
    logger.info(`Email sent successfully to ${to}`);
    return true;
  } catch (error) {
    logger.error(`Error sending email to ${to}:`, error);
    return false;
  }
}

/**
 * Scheduled function to send email payment reminders
 * Runs daily at 9:00 AM IST (before FCM reminders at 10 AM)
 */
exports.sendEmailReminders = onSchedule({
  schedule: "0 9 * * *", // Every day at 9:00 AM
  timeZone: "Asia/Kolkata",
  region: "asia-south1",
}, async (event) => {
  logger.info("Starting email reminder job");

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
      const semesterEndDate = semester.endDate.toDate();
      const daysUntilSemesterEnd = Math.ceil(
        (semesterEndDate - nowDate) / (1000 * 60 * 60 * 24),
      );

      logger.info(`Semester ${semDoc.id} ends in ${daysUntilSemesterEnd} days`);

      // 1. CHECK SEMESTER END REMINDERS (New Logic)
      if ([7, 3, 1].includes(daysUntilSemesterEnd)) {
        logger.info(`Sending ${daysUntilSemesterEnd}-day semester end reminder for batch ${semester.academicYear}`);

        // Find all students in this batch
        const studentsSnapshot = await db.collection("users")
          .where("role", "==", "student")
          .where("batch", "==", semester.academicYear)
          .get();

        for (const studentDoc of studentsSnapshot.docs) {
          const student = studentDoc.data();

          // Check if total dues are cleared
          const totalFee = student.totalFee || 0;
          const paidFee = student.paidFee || 0;

          if (paidFee < totalFee && student.email) {
            const emailSubject = `⚠️ Final Reminder: Semester Ending in ${daysUntilSemesterEnd} Day${daysUntilSemesterEnd > 1 ? "s" : ""}`;
            const emailHtml = `
              <h2>Dear ${student.name},</h2>
              <p>Your semester is ending on ${semesterEndDate.toLocaleDateString("en-IN")}.</p>
              <p>Our records show that you still have outstanding dues of <strong>₹${totalFee - paidFee}</strong>.</p>
              <p>Please clear all dues to be eligible for your <strong>No-Dues Certificate</strong> and exams.</p>
              <a href="https://apec-no-dues.web.app" style="padding: 10px 20px; background: #f44336; color: white; text-decoration: none; border-radius: 5px;">Clear Dues Now</a>
            `;

            await sendEmail(student.email, emailSubject, emailHtml);
          }
        }
      }

      // 2. EXISTING FEE STRUCTURE DEADLINE REMINDERS
      const feeStructuresSnapshot = await db.collection("fee_structures")
        .where("semester", "==", semDoc.id)
        .get();

      for (const feeDoc of feeStructuresSnapshot.docs) {
        const feeStructure = feeDoc.data();
        if (!feeStructure.deadline) continue;

        const deadline = feeStructure.deadline.toDate();
        const daysUntilDeadline = Math.ceil(
          (deadline - nowDate) / (1000 * 60 * 60 * 24),
        );

        // Send reminders at 7, 3, and 1 day(s) before deadline
        if ([7, 3, 1].includes(daysUntilDeadline)) {
          logger.info(
            `Sending ${daysUntilDeadline}-day reminder for ` +
            `${feeStructure.dept} - ${feeStructure.quotaCategory}`,
          );

          // Get students who haven't paid
          const studentsSnapshot = await db.collection("users")
            .where("role", "==", "student")
            .where("dept", "==", feeStructure.dept)
            .where("quotaCategory", "==", feeStructure.quotaCategory)
            .get();

          for (const studentDoc of studentsSnapshot.docs) {
            const student = studentDoc.data();

            // Check if student has paid for this semester
            const paymentsSnapshot = await db.collection("payments")
              .where("studentId", "==", studentDoc.id)
              .where("semester", "==", semDoc.id)
              .where("status", "==", "verified")
              .limit(1)
              .get();

            if (paymentsSnapshot.empty && student.email) {
              // Student hasn't paid - send email
              const emailSubject = `Payment Reminder: ${daysUntilDeadline} Day${daysUntilDeadline > 1 ? "s" : ""} Left`;

              const emailHtml = `
                <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee;">
                  <h2>Hello ${student.name},</h2>
                  <p>This is a reminder that the deadline for <strong>${feeStructure.feeName || 'your fee payment'}</strong> is in ${daysUntilDeadline} days.</p>
                  <p><strong>Deadline:</strong> ${deadline.toLocaleDateString("en-IN")}</p>
                  <p><strong>Amount:</strong> ₹${feeStructure.amount}</p>
                  <p>Please log in to the APEC No-Dues portal to complete your payment.</p>
                </div>
              `;

              await sendEmail(student.email, emailSubject, emailHtml);
            }
          }
        }
      }
    }

    logger.info("Email reminder job completed successfully");
  } catch (error) {
    logger.error("Error in email reminder job:", error);
    throw error;
  }
});

/**
 * Send email notification when payment status changes
 */
exports.sendPaymentStatusEmail = async (paymentData, studentEmail, studentName) => {
  const status = paymentData.status;
  let subject = "";
  let htmlContent = "";

  if (status === "verified") {
    subject = "✅ Payment Verified - APEC No-Dues";
    htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #4CAF50; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background: #f9f9f9; }
          .success { 
            background: #4CAF50; 
            color: white; 
            padding: 15px; 
            border-radius: 5px; 
            margin: 20px 0; 
            text-align: center; 
          }
          .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Payment Verified!</h1>
          </div>
          <div class="content">
            <h2>Dear ${studentName},</h2>
            <div class="success">
              <h3>✅ Your payment has been verified!</h3>
            </div>
            <h3>Payment Details:</h3>
            <ul>
              <li><strong>Amount:</strong> ₹${paymentData.amount}</li>
              <li><strong>Transaction ID:</strong> ${paymentData.transactionId}</li>
              <li><strong>Status:</strong> Verified</li>
            </ul>
            <p>You can now download your No-Dues certificate from the app.</p>
          </div>
          <div class="footer">
            <p>APEC Digital No-Dues System</p>
          </div>
        </div>
      </body>
      </html>
    `;
  } else if (status === "rejected") {
    subject = "❌ Payment Rejected - APEC No-Dues";
    htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #f44336; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; background: #f9f9f9; }
          .error { 
            background: #f44336; 
            color: white; 
            padding: 15px; 
            border-radius: 5px; 
            margin: 20px 0; 
          }
          .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Payment Rejected</h1>
          </div>
          <div class="content">
            <h2>Dear ${studentName},</h2>
            <div class="error">
              <h3>❌ Your payment submission was rejected</h3>
            </div>
            <p><strong>Reason:</strong> ${paymentData.rejectionReason || "Please contact admin"}</p>
            <p>Please resubmit your payment with the correct details.</p>
          </div>
          <div class="footer">
            <p>APEC Digital No-Dues System</p>
          </div>
        </div>
      </body>
      </html>
    `;
  }

  if (studentEmail && subject) {
    await sendEmail(studentEmail, subject, htmlContent);
  }
};
