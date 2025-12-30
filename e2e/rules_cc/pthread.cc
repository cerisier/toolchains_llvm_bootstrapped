#include <pthread.h>

#include <cstdint>

struct SharedState {
  pthread_mutex_t mutex;
  pthread_cond_t cond;
  pthread_key_t tls_key;
  int waiting;
  int ready;
  int value;
};

static void* worker(void* arg) {
  SharedState* state = static_cast<SharedState*>(arg);
  int status = 0;

  const void* tls_marker =
      reinterpret_cast<void*>(static_cast<intptr_t>(0x1234));
  if (pthread_setspecific(state->tls_key, const_cast<void*>(tls_marker)) != 0) {
    return reinterpret_cast<void*>(static_cast<intptr_t>(10));
  }

  if (pthread_mutex_lock(&state->mutex) != 0) {
    return reinterpret_cast<void*>(static_cast<intptr_t>(11));
  }

  state->waiting = 1;
  if (pthread_cond_signal(&state->cond) != 0) {
    status = 12;
  }

  while (status == 0 && state->ready == 0) {
    if (pthread_cond_wait(&state->cond, &state->mutex) != 0) {
      status = 13;
      break;
    }
  }

  if (status == 0 && pthread_getspecific(state->tls_key) != tls_marker) {
    status = 14;
  }

  if (status == 0) {
    state->value += 1;
  }

  if (pthread_mutex_unlock(&state->mutex) != 0 && status == 0) {
    status = 15;
  }

  return reinterpret_cast<void*>(static_cast<intptr_t>(status));
}

int main() {
  SharedState state = {
      PTHREAD_MUTEX_INITIALIZER,
      PTHREAD_COND_INITIALIZER,
      0,
      0,
      0,
      41,
  };

  if (pthread_key_create(&state.tls_key, nullptr) != 0) {
    return 1;
  }

  pthread_t thread;
  if (pthread_create(&thread, nullptr, worker, &state) != 0) {
    pthread_key_delete(state.tls_key);
    return 2;
  }

  if (pthread_mutex_lock(&state.mutex) != 0) {
    pthread_key_delete(state.tls_key);
    return 3;
  }

  while (state.waiting == 0) {
    if (pthread_cond_wait(&state.cond, &state.mutex) != 0) {
      pthread_mutex_unlock(&state.mutex);
      pthread_key_delete(state.tls_key);
      return 4;
    }
  }

  state.ready = 1;
  if (pthread_cond_signal(&state.cond) != 0) {
    pthread_mutex_unlock(&state.mutex);
    pthread_key_delete(state.tls_key);
    return 5;
  }

  if (pthread_mutex_unlock(&state.mutex) != 0) {
    pthread_key_delete(state.tls_key);
    return 6;
  }

  void* result = nullptr;
  if (pthread_join(thread, &result) != 0) {
    pthread_key_delete(state.tls_key);
    return 7;
  }

  if (pthread_key_delete(state.tls_key) != 0) {
    return 8;
  }

  const int worker_status = static_cast<int>(reinterpret_cast<intptr_t>(result));
  if (worker_status != 0) {
    return 20 + worker_status;
  }

  if (state.value != 42) {
    return 40;
  }

  return 0;
}
