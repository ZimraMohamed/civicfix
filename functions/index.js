const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// Must match the location of your Firestore database (e.g. "nam5" -> "us-central1").
const REGION = "us-central1";

const STATUS_TITLES = {
  open: "Open",
  in_progress: "In progress",
  resolved: "Resolved",
};

const DEAD_TOKEN_CODES = [
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
];

/** All saved devices for one user: [{ ref, token }]. */
async function devicesFor(uid) {
  const snap = await db.collection("users").doc(uid).collection("devices").get();
  return snap.docs.map((d) => ({ ref: d.ref, token: d.id }));
}

/** Sends one notification to many devices and deletes tokens FCM says are dead. */
async function send(devices, notification, data) {
  if (devices.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens: devices.map((d) => d.token),
    notification,
    data,
    apns: { payload: { aps: { sound: "default" } } },
  });

  const cleanup = [];
  response.responses.forEach((r, i) => {
    if (!r.success && DEAD_TOKEN_CODES.includes(r.error?.code)) {
      cleanup.push(devices[i].ref.delete());
    }
  });
  await Promise.all(cleanup);
}

/** A user submitted a report -> notify every admin (except the submitter). */
exports.notifyAdminsOfNewReport = onDocumentCreated(
  { document: "reports/{reportId}", region: REGION },
  async (event) => {
    const report = event.data?.data();
    if (!report) return;

    const admins = await db.collection("users").where("roles", "array-contains", "admin").get();
    const adminIds = admins.docs.map((d) => d.id).filter((id) => id !== report.uid);

    const lists = await Promise.all(adminIds.map(devicesFor));
    const devices = lists.flat();

    const tags = (report.hashtags || []).map((t) => `#${t}`).join(" ");
    const summary = (report.details || "").trim() || tags || "A new issue was reported.";

    await send(
      devices,
      {
        title: `New report from ${report.userName || "a citizen"}`,
        body: summary.length > 120 ? `${summary.slice(0, 117)}…` : summary,
      },
      { type: "new_report", reportId: event.params.reportId }
    );
  }
);

/** An admin changed a report's status -> notify the person who submitted it. */
exports.notifyReporterOfStatusChange = onDocumentUpdated(
  { document: "reports/{reportId}", region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status || !after.uid) return;

    const devices = await devicesFor(after.uid);
    const label = STATUS_TITLES[after.status] || after.status;

    await send(
      devices,
      {
        title: "Your report was updated",
        body: `Status changed to “${label}”.`,
      },
      { type: "status_changed", reportId: event.params.reportId, status: after.status }
    );
  }
);
