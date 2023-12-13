##########################
### Secure credentials ###
##########################

# New Relic account ID
resource "newrelic_synthetics_secure_credential" "account_id" {
  key         = "NEW_RELIC_ACCOUNT_ID"
  value       = var.NEW_RELIC_ACCOUNT_ID
  description = "New Relic account ID to which the custom events will be ingested."
}

# New Relic API key
resource "newrelic_synthetics_secure_credential" "api_key" {
  key         = "NEW_RELIC_API_KEY"
  value       = var.NEW_RELIC_API_KEY
  description = "New Relic API key with which the dashboard URL will be created per GraphQL."
}

# New Relic license key
resource "newrelic_synthetics_secure_credential" "license_key" {
  key         = "NEW_RELIC_LICENSE_KEY"
  value       = var.NEW_RELIC_LICENSE_KEY
  description = "New Relic license key for ingesting custom events into New Relic."
}
######

########################
### Synthetic script ###
########################

# Script to create custom events with dashboard page URL
resource "newrelic_synthetics_script_monitor" "monitor" {
  status           = "ENABLED"
  name             = "my-snapshot-exporter-script"
  type             = "SCRIPT_API"
  locations_public = ["AWS_EU_CENTRAL_1", "AWS_US_WEST_1"]
  period           = "EVERY_DAY"

  script = <<EOF
  let assert = require("assert");

  const NEWRELIC_GRAPHQL_ENDPOINT =
    $secure.NEWRELIC_LICENSE_KEY.substring(0, 2) === "eu"
      ? "https://api.eu.newrelic.com/graphql"
      : "https://api.newrelic.com/graphql";

  const CUSTOM_EVENT_NAME = "${local.custom_event_name}";

  const NEWRELIC_EVENTS_ENDPOINT =
    $secure.NEWRELIC_LICENSE_KEY.substring(0, 2) === "eu"
      ? `https://insights-collector.eu01.nr-data.net/v1/accounts/$${$secure.NEWRELIC_ACCOUNT_ID}/events`
      : `https://insights-collector.nr-data.net/v1/accounts/$${$secure.NEWRELIC_ACCOUNT_ID}/events`;

  /**
  * Makes an HTTP POST request.
  * @param {object} options
  * @returns {object[]} Response body
  */
  const makeHttpPostRequest = async function (options) {
    let responseBody;

    await $http.post(options, function (err, res, body) {
      console.log(`Status code: $${res.statusCode}`);
      if (err) {
        assert.fail(`Post request has failed: $${err}`);
      } else {
        if (res.statusCode == 200) {
          console.log("Post request is performed successfully.");
          responseBody = res.body;
        } else {
          console.log("Post request returned not OK result.");
          console.log(res.body);
          assert.fail("Failed.");
        }
      }
    });

    return JSON.parse(responseBody);
  };

  /**
  * Prepares GraphQl query for generating dashboard snapshot URL
  * @returns GraphQL query body
  */
  const createGraphqlQueryBody = function () {
    console.log("Creating GraphQL request body...")
    return {
      query: `mutation {
        dashboardCreateSnapshotUrl(guid: "${newrelic_one_dashboard.dashboard.page[0].guid}")
      }`,
    };
  };

  /**
  * Makes request to GraphQL endpoint and returns NRQL query result
  * @param {string} graphqlQueryBody Body of the GraphQL query
  * @returns {object} NRQL query result
  */
  const makeGraphQlNrqlRequest = async function (graphqlQueryBody) {
    const options = {
      url: NEWRELIC_GRAPHQL_ENDPOINT,
      headers: {
        "Content-Type": "application/json",
        "Api-Key": $secure.NEWRELIC_USER_API_KEY,
      },
      body: JSON.stringify(graphqlQueryBody),
    };

    console.log("Performing GraphQL request...");
    const responseBody = await makeHttpPostRequest(options);
    return responseBody;
  };

  /**
  * Generates dashboard snapshot URL
  * @param {string} query NRQL query
  * @returns {number} Dashboard snapshot URL
  */
  const generateDashboardSnaphotUrl = async function () {
    const graphqlQuery = createGraphqlQueryBody();
    const result = await makeGraphQlNrqlRequest(graphqlQuery);
    console.log("GraphQL response: " + result);
    return result["data"]["dashboardCreateSnapshotUrl"];
  };

  /**
  * Flushes the created custom events to New Relic events endpoint.
  * @param {object[]} customEvents
  */
  const flushCustomEvent = async function (customEvents) {
    let options = {
      url: NEWRELIC_EVENTS_ENDPOINT,
      headers: {
        "Content-Type": "application/json",
        "Api-Key": $secure.NEWRELIC_LICENSE_KEY,
      },
      body: JSON.stringify(customEvents),
    };

    await makeHttpPostRequest(options);
  };

  /**
  * Creates custom event with the dashboard page snapshot URL as attribute
  * @param {number} dashboardSnapshotUrl URL for the PDF snaphot of the dashboard page
  */
  const createCustomEvent = async function (dashboardSnapshotUrl) {
    let customEvents = [];

    customEvents.push({
      eventType: CUSTOM_EVENT_NAME,
      snapshotURL: dashboardSnapshotUrl,
    });

    await flushCustomEvent(customEvents);
  };

  // -------------------- //
  // --- SCRIPT START --- //
  // -------------------- //
  try {
    // Generate dashboard URL
    const dashboardSnapshotUrl = await generateDashboardSnaphotUrl();

    // Create custom event
    await createCustomEvent(dashboardSnapshotUrl);
  } catch (e) {
    console.log("Unexpected errors occured: ", e);
    assert.fail("Failed.");
  }
  // -------------------- //
  EOF

  script_language      = "JAVASCRIPT"
  runtime_type         = "NODE_API"
  runtime_type_version = "16.10"
}
