# CF MySQL Broker

This is the broker for a new Cloud Foundry MySQL service that demonstrates the v2 Services API.

### The new services API is still in progress and may change at any time. Do not build a broker against this API.

## API

During development you can inspect the current API routes:

```
$ rake routes
                             Prefix Verb   URI Pattern                                                               Controller#Action
                         v2_catalog GET    /v2/catalog(.:format)                                                     v2/catalogs#show
v2_service_instance_service_binding PATCH  /v2/service_instances/:service_instance_id/service_bindings/:id(.:format) v2/service_bindings#update
                                    PUT    /v2/service_instances/:service_instance_id/service_bindings/:id(.:format) v2/service_bindings#update
                                    DELETE /v2/service_instances/:service_instance_id/service_bindings/:id(.:format) v2/service_bindings#destroy
                v2_service_instance PATCH  /v2/service_instances/:id(.:format)                                       v2/service_instances#update
                                    PUT    /v2/service_instances/:id(.:format)                                       v2/service_instances#update
                                    DELETE /v2/service_instances/:id(.:format)                                       v2/service_instances#destroy
```

## Local usage

In one terminal:

```
$ bundle
$ rake db:create:all
$ bin/rails s
```

In another terminal:

```
$ curl http://cc:secret@localhost:3000/v2/catalog
```

To see the output in a pretty format:

```
$ gem install jazor
$ curl http://cc:secret@localhost:3000/v2/catalog | jazor
```

Outputs:

``` json
{
  "services": [
    {
      "id": "cf-mysql-1",
      "name": "cf-mysql2",
      "description": "Cloud Foundry MySQL",
      "tags": [
        "mysql",
        "relational"
      ],
      "metadata": {
        "listing": {
          "imageUrl": null,
          "blurb": "MySQL service for application development and testing"
        }
      },
      "plans": [
        {
          "id": "cf-mysql-plan-1",
          "name": "free2",
          "description": "Free Trial",
          "metadata": {
            "cost": 0.0,
            "bullets": [
              {
                "content": "Shared MySQL server"
              },
              {
                "content": "100 MB storage"
              },
              {
                "content": "40 concurrent connections"
              }
            ]
          }
        }
      ],
      "bindable": true
    }
  ]
}
```

This output matches the plans described in `config/settings.yml`.
