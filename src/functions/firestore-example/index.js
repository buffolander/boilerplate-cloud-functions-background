require('dotenv').config()

const functions = require('firebase-functions')

const { firestore: trigger } = functions

const handler = trigger.document('collection/{id}').onWrite(async (change, context) => {
  const { params: { id: documentId } } = context
  console.info(documentId)

  const beforeData = change.before.data()
  const afterData = change.after.data()
  return console.info('Done')
})

module.exports = { handler }

/*
 * Alternative events
  [onCreate, onDelete]((snap, context) => { const doc = snap.data() })
  [onUpdate, onWrite]((change, context) => { const after = change.after.data() })
*/
