# Email Service Setup Guide

## Overview
The email service provides an alternative/supplement to FCM notifications by sending HTML emails for payment reminders and status updates.

## Prerequisites
- SendGrid account (free tier available)
- SendGrid API key
- Verified sender email address

## Setup Instructions

### 1. Create SendGrid Account
1. Go to [SendGrid](https://sendgrid.com/)
2. Sign up for free account (100 emails/day free)
3. Verify your email address

### 2. Create API Key
1. Go to Settings → API Keys
2. Click "Create API Key"
3. Name: `APEC-No-Dues-Email`
4. Permissions: Full Access
5. Copy the API key (you won't see it again!)

### 3. Verify Sender Email
1. Go to Settings → Sender Authentication
2. Click "Verify a Single Sender"
3. Enter: `noreply@apec.edu.in` (or your domain)
4. Fill in organization details
5. Verify email via link sent to your inbox

### 4. Install Dependencies
```bash
cd functions
npm install @sendgrid/mail
```

### 5. Set Environment Variable
```bash
firebase functions:config:set sendgrid.api_key="YOUR_SENDGRID_API_KEY"
```

### 6. Update email_service.js
Uncomment the SendGrid code in `functions/email_service.js`:

```javascript
// Remove comments from these lines:
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

// And in sendEmail function, uncomment:
const msg = {
  to: to,
  from: 'noreply@apec.edu.in', // Your verified sender
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
```

### 7. Update functions/index.js
Add this line to import email service:
```javascript
const emailService = require('./email_service');
```

Export the email functions:
```javascript
exports.sendEmailReminders = emailService.sendEmailReminders;
```

### 8. Deploy Functions
```bash
firebase deploy --only functions
```

## Email Templates

### Payment Reminder Email
- Sent at 7, 3, and 1 day(s) before deadline
- Color-coded urgency (orange for 7 days, red for 1-3 days)
- Includes payment details and deadline
- Call-to-action button

### Payment Verified Email
- Green success theme
- Shows verified payment details
- Mentions No-Dues certificate availability

### Payment Rejected Email
- Red error theme
- Shows rejection reason
- Encourages resubmission

## Testing

### Test Email Sending
```javascript
// In Firebase Console → Functions → sendEmailReminders
// Click "Run function" to test manually
```

### Check Logs
```bash
firebase functions:log --only sendEmailReminders
```

## Monitoring

### SendGrid Dashboard
- View email delivery stats
- Check bounce rates
- Monitor spam reports

### Firebase Logs
- All email sends are logged to Firestore `notifications` collection
- Check `sent` field to see if email was successful

## Troubleshooting

### Email Not Sending
1. Check API key is set correctly
2. Verify sender email is verified in SendGrid
3. Check Firebase function logs for errors
4. Ensure student has valid email in Firestore

### Email Going to Spam
1. Set up SPF/DKIM in SendGrid
2. Use verified domain instead of generic email
3. Avoid spam trigger words in subject/body

### Rate Limits
- Free tier: 100 emails/day
- Upgrade to Essentials ($19.95/month) for 40,000 emails/month

## Alternative Email Services

### Nodemailer (Gmail)
```bash
npm install nodemailer
```

```javascript
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'your-email@gmail.com',
    pass: 'your-app-password' // Use App Password, not regular password
  }
});

async function sendEmail(to, subject, htmlContent) {
  const mailOptions = {
    from: 'your-email@gmail.com',
    to: to,
    subject: subject,
    html: htmlContent
  };
  
  await transporter.sendMail(mailOptions);
}
```

### AWS SES
- More cost-effective for high volume
- $0.10 per 1,000 emails
- Requires AWS account

## Best Practices

1. **Timing**: Send emails at 9 AM (before FCM at 10 AM)
2. **Frequency**: Don't send more than 1 email per day per student
3. **Content**: Keep emails concise and actionable
4. **Unsubscribe**: Add unsubscribe link for compliance
5. **Testing**: Always test with your own email first

## Cost Estimation

### SendGrid Free Tier
- 100 emails/day = 3,000 emails/month
- Suitable for ~100 students with 3 reminders each

### SendGrid Essentials ($19.95/month)
- 40,000 emails/month
- Suitable for ~1,000 students

### For APEC (assuming 500 students)
- 3 reminders per student = 1,500 emails/month
- Free tier is sufficient!

## Email vs FCM

| Feature | Email | FCM |
|---------|-------|-----|
| Delivery | Reliable | Requires app installed |
| Cost | Free tier limited | Free unlimited |
| Rich Content | HTML templates | Limited formatting |
| Offline | Works | Requires internet |
| User Preference | Universal | App-dependent |

**Recommendation**: Use both for maximum reach!

---

*Last Updated: February 4, 2026*
