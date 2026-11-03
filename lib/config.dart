/// Настройки онлайн-приёма заявок.
///
/// Supabase → Project Settings → API:
///   supabaseUrl  — Project URL
///   supabaseAnonKey — anon public key (его можно хранить в приложении,
///                     доступ ограничен RLS-политиками в schema.sql)
///
/// siteUrl — адрес страницы заявок на GitHub Pages (без ?t=).
/// Пока supabaseUrl пустой — приложение работает полностью офлайн, как раньше.
const supabaseUrl = 'https://lxzoqghiidmgobiwehuj.supabase.co';
const supabaseAnonKey = 'sb_publishable_iT1w3dpzoAu6WER8jbiKKw_BFAYQXBm';
const siteUrl = 'https://georgiy-mez.github.io/wrestling_brackets/';

bool get onlineConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
