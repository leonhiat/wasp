import axios, { type AxiosError } from 'axios'

import config from './config'
import { storage } from './storage'
import { apiEventsEmitter } from './api/events'

const api = axios.create({
  baseURL: config.apiUrl,
})

const WASP_APP_AUTH_TOKEN_NAME = 'authToken'

let authToken = storage.get(WASP_APP_AUTH_TOKEN_NAME) as string | undefined

export function setAuthToken(token: string): void {
  authToken = token
  storage.set(WASP_APP_AUTH_TOKEN_NAME, token)
  apiEventsEmitter.emit('authToken.set')
}

export function getAuthToken(): string | undefined {
  return authToken
}

export function clearAuthToken(): void {
  authToken = undefined
  storage.remove(WASP_APP_AUTH_TOKEN_NAME)
  apiEventsEmitter.emit('authToken.clear')
}

export function removeLocalUserData(): void {
  authToken = undefined
  storage.clear()
  apiEventsEmitter.emit('authToken.clear')
}

api.interceptors.request.use((request) => {
  if (authToken) {
    request.headers['Authorization'] = `Bearer ${authToken}`
  }
  return request
})

api.interceptors.response.use(undefined, (error) => {
  if (error.response?.status === 401) {
    clearAuthToken()
  }
  return Promise.reject(error)
})

// This handler will run on other tabs (not the active one calling API functions),
// and will ensure they know about auth token changes.
// Ref: https://developer.mozilla.org/en-US/docs/Web/API/Window/storage_event
// "Note: This won't work on the same page that is making the changes — it is really a way
// for other pages on the domain using the storage to sync any changes that are made."
window.addEventListener('storage', (event) => {
  if (event.key === storage.getPrefixedKey(WASP_APP_AUTH_TOKEN_NAME)) {
    if (!!event.newValue) {
      authToken = event.newValue
      apiEventsEmitter.emit('authToken.set')
    } else {
      authToken = undefined
      apiEventsEmitter.emit('authToken.clear')
    }
  }
})

/**
 * Takes an error returned by the app's API (as returned by axios), and transforms into a more
 * standard format to be further used by the client. It is also assumed that given API
 * error has been formatted as implemented by HttpError on the server.
 */
export function handleApiError(error: AxiosError<{ message?: string, data?: unknown }>): void {
  if (error?.response) {
    // If error came from HTTP response, we capture most informative message
    // and also add .statusCode information to it.
    // If error had JSON response, we assume it is of format { message, data } and
    // add that info to the error.
    // TODO: We might want to use HttpError here instead of just Error, since
    //   HttpError is also used on server to throw errors like these.
    //   That would require copying HttpError code to web-app also and using it here.
    const responseJson = error.response?.data
    const responseStatusCode = error.response.status
    throw new WaspHttpError(responseStatusCode, responseJson?.message ?? error.message, responseJson)
  } else {
    // If any other error, we just propagate it.
    throw error
  }
}

class WaspHttpError extends Error {
  statusCode: number

  data: unknown

  constructor (statusCode: number, message: string, data: unknown) {
    super(message)
    this.statusCode = statusCode
    this.data = data
  }
}

export default api
