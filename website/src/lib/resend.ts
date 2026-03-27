import { Resend } from "resend";

let resendClient: Resend | null = null;

export function getResendClient(apiKey: string) {
  if (!resendClient) {
    resendClient = new Resend(apiKey);
  }

  return resendClient;
}

