import type { SSEMessage } from './types';

export function createSSEStream(): {
  send: (msg: SSEMessage) => void;
  close: () => void;
  response: Response;
} {
  let controller!: ReadableStreamDefaultController<Uint8Array>;

  const stream = new ReadableStream<Uint8Array>({
    start(c) {
      controller = c;
    },
  });

  function send(msg: SSEMessage): void {
    const data = `data: ${JSON.stringify(msg)}\n\n`;
    controller.enqueue(new TextEncoder().encode(data));
  }

  function close(): void {
    try {
      controller.close();
    } catch {
      /* already closed */
    }
  }

  const response = new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  });

  return { send, close, response };
}
