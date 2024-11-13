self.addEventListener("push", function(event){
  var event_data = event.data.json();

  var title = event_data.title;
  delete event_data.title

  event.waitUntil(
    self.registration.showNotification(title, event_data)
  );
});

self.addEventListener("notificationclick", function(event){
  event.notification.close();

  var data = event.notification.data || {};

  // here is where you can send the "delivered" update back the server

  event.waitUntil(
    self.clients.openWindow(data.url)
  );
});
