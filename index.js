var AWS = require('aws-sdk')

const athena = new AWS.Athena()

exports.startQuery = (event, context, callback) => {
  const params = {
    QueryString: event.query,
    ResultConfiguration: {
      OutputLocation: event.outputLocation
    }
  }
  athena.startQueryExecution(params, (error, data) => {
    if (error) {
      callback(error)
    } else {
      const response = {
        queryExecutionId: data.QueryExecutionId,
        waitTime: 1
      }
      callback(null, response)
    }
  })
}

exports.pollStatus = (event, context, callback) => {
  const params = {
    QueryExecutionId: event.queryExecutionId
  }
  athena.getQueryExecution(params, (error, data) => {
    if (error) {
      callback(error)
    } else {
      const response = {
        queryExecutionId: data.QueryExecution.QueryExecutionId,
        status: data.QueryExecution.Status.State,
        waitTime: event.waitTime * 2,
      }
      callback(null, response)
    }
  })
}

exports.getResults = (event, context, callback) => {
  const params = {
    QueryExecutionId: event.queryExecutionId,
    MaxResults: 5
  }
  athena.getQueryResults(params, callback)
}
