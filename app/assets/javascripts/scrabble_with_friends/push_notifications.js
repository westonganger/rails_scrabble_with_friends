ENGINE_MOUNT_PATH = null;

document.addEventListener('DOMContentLoaded', function(){
  // Check if the browser supports notifications
  if("Notification" in window) {
    // Request permission from the user to send notifications
    Notification
      .requestPermission()
      .then(function(permission){
        if(permission === "granted"){
          // If permission is granted, register the service worker
          registerServiceWorker();
        }else if(permission === "denied"){
          console.warn("User rejected to allow notifications.");
        }else{
          console.warn("User still didn't give an answer about notifications.");
        }
      });
  }else{
    console.warn("Push notifications not supported.");
  }

  var registerServiceWorker = function(){
    // Check if the browser supports service workers
    if ("serviceWorker" in navigator) {
      // Register the service worker script (service_worker.js)
      navigator.serviceWorker
        .register(`${MOUNT_PATH}service_worker.js`)
        .then(function(serviceWorkerRegistration){
          // Check if a subscription to push notifications already exists
          serviceWorkerRegistration.pushManager
            .getSubscription()
            .then(function(existingSubscription){
              if(!existingSubscription){
                // If no subscription exists, subscribe to push notifications
                subscribe();
              }
            });
        })
        .catch(function(error){
          console.error("Error during registration Service Worker:", error);
        });
    }
  };

  var subscribe = function(){
    serviceWorkerRegistration.pushManager
      .subscribe({
        userVisibleOnly: true,
        applicationServerKey: "<%= ENV[WEB_PUSH_APPLICATION_SERVER_KEY] %>",
      })
      .then(function(subscription){
        saveSubscriptionToBackend(subscription);
      });
  };

  var saveSubscriptionToBackend = function(subscription){
    // Extract necessary subscription data

    var data = {
      endpoint: subscription.endpoint,
      p256dh: btoa(
        String.fromCharCode.apply(
          null,
          new Uint8Array(subscription.getKey("p256dh"))
        )
      ),
      auth: btoa(
        String.fromCharCode.apply(
          null,
          new Uint8Array(subscription.getKey("auth"))
        )
      ),
    };

    csrf_token = document.querySelector('meta[name="csrf-token"]').getAttribute("content");

    // Send the subscription data to the server
    fetch("/admin/push_notifications/subscribe", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": csrf_token,
      },
      body: JSON.stringify(data),
    }).then(function(response){
      if(response.ok){
        console.log("Subscription successfully saved on the server.");
      } else {
        console.error("Error saving subscription on the server.");
      }
    }).catch(function(error){
      console.error("Error sending subscription to the server:", error);
    });
  }
}
