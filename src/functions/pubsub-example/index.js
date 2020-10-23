require('dotenv').config()

const handler = (message, context) => {
  console.info(`eventType=${context.eventType} | eventId=${context.eventId}`)
  let { data: payload } = message
  if (!payload) return

  payload = Buffer.from(message.data, 'base64').toString()
  payload = JSON.parse(payload)

  return console.info(JSON.stringify(payload))
}

module.exports = { handler }
