import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const whatsappToken = Deno.env.get("WHATSAPP_ACCESS_TOKEN")!;
const whatsappPhoneNumberId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID")!;
const whatsappTemplateName =
    Deno.env.get("WHATSAPP_TEMPLATE_NAME") ?? "appointment_reminder";
const whatsappTemplateLanguage =
    Deno.env.get("WHATSAPP_TEMPLATE_LANGUAGE") ?? "pt_BR";

const supabase = createClient(
    supabaseUrl,
    supabaseServiceRoleKey,
);

function getBrazilDate(): string {
    const formatter = new Intl.DateTimeFormat("en-CA", {
        timeZone: "America/Sao_Paulo",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
    });

    return formatter.format(new Date());
}

function getTomorrowDate(): string {
    const now = new Date();

    const brazilDate = new Date(
        new Intl.DateTimeFormat("en-US", {
            timeZone: "America/Sao_Paulo",
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
        }).format(now),
    );

    brazilDate.setDate(brazilDate.getDate() + 1);

    const year = brazilDate.getFullYear();
    const month = String(brazilDate.getMonth() + 1).padStart(2, "0");
    const day = String(brazilDate.getDate()).padStart(2, "0");

    return `${year}-${month}-${day}`;
}

function formatPhone(phone: string): string {
    let clean = phone.replace(/\D/g, "");

    if (clean.startsWith("0")) {
        clean = clean.substring(1);
    }

    if (!clean.startsWith("55")) {
        clean = `55${clean}`;
    }

    return clean;
}

function formatDate(date: string): string {
    const [year, month, day] = date.split("-");

    return `${day}/${month}/${year}`;
}

async function sendWhatsAppTemplate(
    phone: string,
    clientName: string,
    date: string,
    time: string,
    serviceName: string,
) {
    const url =
        `https://graph.facebook.com/v23.0/${whatsappPhoneNumberId}/messages`;

    const response = await fetch(url, {
        method: "POST",
        headers: {
            Authorization: `Bearer ${whatsappToken}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            messaging_product: "whatsapp",
            to: phone,
            type: "template",
            template: {
                name: whatsappTemplateName,
                language: {
                    code: whatsappTemplateLanguage,
                },
                components: [
                    {
                        type: "body",
                        parameters: [
                            {
                                type: "text",
                                text: clientName,
                            },
                            {
                                type: "text",
                                text: formatDate(date),
                            },
                            {
                                type: "text",
                                text: time.substring(0, 5),
                            },
                            {
                                type: "text",
                                text: serviceName,
                            },
                        ],
                    },
                ],
            },
        }),
    });

    const result = await response.json();

    if (!response.ok) {
        console.error("Erro WhatsApp:", result);

        throw new Error(
            `WhatsApp API error: ${JSON.stringify(result)}`,
        );
    }

    return result;
}

Deno.serve(async () => {
    try {
        if (
            !whatsappToken ||
            !whatsappPhoneNumberId
        ) {
            return new Response(
                JSON.stringify({
                    error: "Credenciais do WhatsApp não configuradas.",
                }),
                {
                    status: 500,
                    headers: {
                        "Content-Type": "application/json",
                    },
                },
            );
        }

        const tomorrow = getTomorrowDate();

        console.log(
            `Procurando atendimentos para ${tomorrow}`,
        );

        const { data: appointments, error } = await supabase
            .from("appointments")
            .select(`
        id,
        user_id,
        appointment_date,
        appointment_time,
        reminder_sent_at,
        clients (
          name,
          phone
        ),
        services (
          name
        )
      `)
            .eq("appointment_date", tomorrow)
            .is("reminder_sent_at", null);

        if (error) {
            console.error(error);

            return new Response(
                JSON.stringify({
                    error: error.message,
                }),
                {
                    status: 500,
                    headers: {
                        "Content-Type": "application/json",
                    },
                },
            );
        }

        let sent = 0;
        let skipped = 0;
        let failed = 0;

        for (const appointment of appointments ?? []) {
            try {
                /*
                 * Só usuários do plano pago com lembrete automático ativado
                 * podem chegar até o WhatsApp.
                 */
                const { data: plan, error: planError } = await supabase
                    .from("user_plans")
                    .select("plan, automatic_reminders")
                    .eq("user_id", appointment.user_id)
                    .maybeSingle();

                if (planError) {
                    console.error(
                        `Erro ao consultar plano ${appointment.user_id}:`,
                        planError,
                    );

                    failed++;
                    continue;
                }

                if (
                    !plan ||
                    plan.plan !== "paid" ||
                    plan.automatic_reminders !== true
                ) {
                    skipped++;
                    continue;
                }

                const client = appointment.clients as
                    | {
                        name?: string;
                        phone?: string;
                    }
                    | null;

                const service = appointment.services as
                    | {
                        name?: string;
                    }
                    | null;

                const phone = client?.phone?.trim() ?? "";

                if (!phone) {
                    console.log(
                        `Cliente sem telefone: ${appointment.id}`,
                    );

                    skipped++;
                    continue;
                }

                const cleanPhone = formatPhone(phone);

                await sendWhatsAppTemplate(
                    cleanPhone,
                    client?.name ?? "Cliente",
                    appointment.appointment_date,
                    appointment.appointment_time,
                    service?.name ?? "atendimento",
                );

                await supabase
                    .from("appointments")
                    .update({
                        reminder_sent_at: new Date().toISOString(),
                    })
                    .eq("id", appointment.id);

                sent++;

                console.log(
                    `Lembrete enviado: ${appointment.id}`,
                );
            } catch (error) {
                console.error(
                    `Falha no atendimento ${appointment.id}:`,
                    error,
                );

                failed++;
            }
        }

        return new Response(
            JSON.stringify({
                success: true,
                date: tomorrow,
                sent,
                skipped,
                failed,
            }),
            {
                status: 200,
                headers: {
                    "Content-Type": "application/json",
                },
            },
        );
    } catch (error) {
        console.error(error);

        return new Response(
            JSON.stringify({
                error: error instanceof Error
                    ? error.message
                    : "Erro desconhecido",
            }),
            {
                status: 500,
                headers: {
                    "Content-Type": "application/json",
                },
            },
        );
    }
});