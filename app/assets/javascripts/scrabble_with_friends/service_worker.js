ENGINE_MOUNT_PATH = null;

self.addEventListener("push", event => {
  var data = event.data?.json() || {};

  console.log("Received push", data);

  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      data: data,
      //title: data.title,
      //icon: null,
    });
  );
});

self.addEventListener("notificationclick", function(event){
  event.notification.close();

  var data = event.notification.data || {};

  // here is where you can send the "delivered" update back the server
  console.log(`opening ${data.url}`);

  event.waitUntil(
    self.clients.openWindow(data.url);
  );
});

self.addEventListener("pushsubscriptionchange", async (event) => {
  var subscription = await self.registration.pushManager.getSubscription();

  await fetch(`${ENGINE_MOUNT_PATH}/subscriptions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(subscription),
  })
})
