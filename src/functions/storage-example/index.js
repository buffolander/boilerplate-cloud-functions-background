require('dotenv').config()

const { Storage } = require('@google-cloud/storage')

const handler = (file, context) => {
  console.info(`eventType=${context.eventType} | eventId=${context.eventId}`)
  const {
    bucket,
    name: filename,
    metageneration,
    timeCreated,
    updated: timeUpdated,
  } = file
  if (filename.indexOf('profile-updates/') === -1 || filename.slice(-3) !== 'csv') return

  const storage = new Storage()
  const storageBucket = storage.bucket(bucket)
  const stream = storageBucket.file(filename).createReadStream().pipe(csv.parse({ headers: true }))

  return new Promise((resolve) => {
    stream.on('data', (row) => {
      // process each row/ usually publish to pubSub topic
    })
    stream.on('end', () => {
      console.info('Rows queued for Processing')
      resolve('Done')
    })
  })
}

module.exports = { handler }
